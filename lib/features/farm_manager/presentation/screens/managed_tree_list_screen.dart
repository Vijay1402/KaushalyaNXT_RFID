import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../farmer/tree_details/tree_controller.dart';
import '../farm_manager_data.dart';

class ManagedTreeListScreen extends ConsumerStatefulWidget {
  const ManagedTreeListScreen({super.key});

  @override
  ConsumerState<ManagedTreeListScreen> createState() =>
      _ManagedTreeListScreenState();
}

class _ManagedTreeListScreenState extends ConsumerState<ManagedTreeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _selectedHealth = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTreeDetails(Map<String, dynamic> tree) {
    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    if (treeDocId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This tree record is missing a document id.'),
        ),
      );
      return;
    }

    context.pushNamed(
      'treeDetails',
      extra: treeDocId,
      queryParameters: const {'source': 'myTrees'},
    );
  }

  int _treePriority(Map<String, dynamic> tree) {
    switch (healthLabel(tree['healthStatus'])) {
      case 'Critical':
        return 0;
      case 'At Risk':
        return 1;
      case 'Needs Attention':
        return 2;
      case 'Healthy':
        return 3;
      default:
        return 4;
    }
  }

  List<Map<String, dynamic>> _sortedTrees(List<Map<String, dynamic>> trees) {
    final sortedTrees = List<Map<String, dynamic>>.from(trees);
    sortedTrees.sort((left, right) {
      final priorityCompare =
          _treePriority(left).compareTo(_treePriority(right));
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final leftTreeId =
          firstNonEmptyString([left['treeId']], fallback: 'tree').toLowerCase();
      final rightTreeId = firstNonEmptyString(
        [right['treeId']],
        fallback: 'tree',
      ).toLowerCase();
      return leftTreeId.compareTo(rightTreeId);
    });
    return sortedTrees;
  }

  String _formatDateLabel(Map<String, dynamic> tree) {
    final parsed = parseDateTime(
      tree['lastinspectiondate'] ??
          tree['lastInspectionDate'] ??
          tree['updatedAt'] ??
          tree['createdAt'],
    );
    if (parsed == null) {
      return 'Inspection not available';
    }
    final localDate = parsed.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = _monthLabel(localDate.month);
    final year = localDate.year.toString();
    return 'Last inspection: $day $month $year';
  }

  String _monthLabel(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > months.length) {
      return 'Jan';
    }
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(farmManagerAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Managed Trees'),
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load tree records: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) {
          final issueCountsByTreeDocId = <String, int>{};
          for (final issue in data.issues) {
            final treeDocId = issue.treeDocId.trim();
            if (treeDocId.isEmpty) {
              continue;
            }
            issueCountsByTreeDocId.update(
              treeDocId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }

          final sortedTrees = _sortedTrees(data.trees);
          final filteredTrees = sortedTrees.where((tree) {
            final health = healthLabel(tree['healthStatus']);
            if (_selectedHealth != 'All' && health != _selectedHealth) {
              return false;
            }

            final query = _search.trim().toLowerCase();
            if (query.isEmpty) {
              return true;
            }

            final values = <String>[
              firstNonEmptyString([tree['treeId']]),
              farmNameFromTree(tree),
              farmerNameFromTree(tree),
              firstNonEmptyString([tree['location']]),
              firstNonEmptyString([tree['species']]),
            ];

            return values.any(
              (value) => value.toLowerCase().contains(query),
            );
          }).toList(growable: false);

          final healthyCount = data.trees
              .where((tree) => healthLabel(tree['healthStatus']) == 'Healthy')
              .length;
          final atRiskCount = data.trees
              .where(
                (tree) => const {'At Risk', 'Critical'}
                    .contains(healthLabel(tree['healthStatus'])),
              )
              .length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Managed Trees',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203423),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Browse every tree linked to the farmers in this farm manager scope.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TreeStatCard(
                            title: 'Total Trees',
                            value: '${data.trees.length}',
                            icon: Icons.park_outlined,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TreeStatCard(
                            title: 'Healthy',
                            value: '$healthyCount',
                            icon: Icons.favorite_outline,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TreeStatCard(
                            title: 'Alerts',
                            value: '$atRiskCount',
                            icon: Icons.warning_amber_rounded,
                            color: atRiskCount == 0
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _search = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Search tree ID, farm, farmer, species, or location',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _HealthFilterChip(
                      label: 'All',
                      active: _selectedHealth == 'All',
                      onTap: () {
                        setState(() {
                          _selectedHealth = 'All';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _HealthFilterChip(
                      label: 'Healthy',
                      active: _selectedHealth == 'Healthy',
                      onTap: () {
                        setState(() {
                          _selectedHealth = 'Healthy';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _HealthFilterChip(
                      label: 'Needs Attention',
                      active: _selectedHealth == 'Needs Attention',
                      onTap: () {
                        setState(() {
                          _selectedHealth = 'Needs Attention';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _HealthFilterChip(
                      label: 'At Risk',
                      active: _selectedHealth == 'At Risk',
                      onTap: () {
                        setState(() {
                          _selectedHealth = 'At Risk';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _HealthFilterChip(
                      label: 'Critical',
                      active: _selectedHealth == 'Critical',
                      onTap: () {
                        setState(() {
                          _selectedHealth = 'Critical';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredTrees.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            data.trees.isEmpty
                                ? 'No tree records are available for this farm manager yet.'
                                : 'No trees match the current search or health filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filteredTrees.length,
                        itemBuilder: (context, index) {
                          final tree = filteredTrees[index];
                          final treeId = firstNonEmptyString(
                            [tree['treeId']],
                            fallback: 'Tree',
                          );
                          final farmLabel = farmNameFromTree(tree);
                          final farmerLabel = farmerNameFromTree(tree);
                          final location = firstNonEmptyString(
                            [tree['location']],
                            fallback: 'Location unavailable',
                          );
                          final species = firstNonEmptyString(
                            [tree['species']],
                            fallback: 'Species not set',
                          );
                          final health = healthLabel(tree['healthStatus']);
                          final treeDocId =
                              (tree['_docId'] ?? '').toString().trim();
                          final issueCount = treeDocId.isEmpty
                              ? 0
                              : (issueCountsByTreeDocId[treeDocId] ?? 0);
                          final isScanned = tree['isScanned'] == true;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _openTreeDetails(tree),
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: healthColor(health)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            Icons.park_outlined,
                                            color: healthColor(health),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                treeId,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$farmLabel  •  $farmerLabel',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF72816F),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _TreeInfoPill(
                                          icon: Icons.favorite_outline,
                                          label: health,
                                          color: healthColor(health),
                                        ),
                                        _TreeInfoPill(
                                          icon: Icons.spa_outlined,
                                          label: species,
                                          color: Colors.green.shade700,
                                        ),
                                        _TreeInfoPill(
                                          icon: Icons.qr_code_2_outlined,
                                          label: isScanned
                                              ? 'Scanned'
                                              : 'Not scanned',
                                          color: isScanned
                                              ? Colors.teal.shade700
                                              : Colors.orange.shade700,
                                        ),
                                        _TreeInfoPill(
                                          icon: Icons.warning_amber_rounded,
                                          label: issueCount == 0
                                              ? 'No issues'
                                              : '$issueCount issues',
                                          color: issueCount == 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      location,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDateLabel(tree),
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TreeStatCard extends StatelessWidget {
  const _TreeStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5F7062),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthFilterChip extends StatelessWidget {
  const _HealthFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.green.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.green.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TreeInfoPill extends StatelessWidget {
  const _TreeInfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

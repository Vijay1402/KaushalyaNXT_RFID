import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/responsive_layout.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import '../../farm_manager/presentation/farm_manager_providers.dart';
import 'admin_confirmation_dialog.dart';
import 'admin_management_forms.dart';
import 'admin_management_service.dart';
import 'admin_tree_detail_screen.dart';

class AdminFarmDetailScreen extends ConsumerStatefulWidget {
  const AdminFarmDetailScreen({
    super.key,
    required this.farmId,
  });

  final String farmId;

  @override
  ConsumerState<AdminFarmDetailScreen> createState() =>
      _AdminFarmDetailScreenState();
}

class _AdminFarmDetailScreenState extends ConsumerState<AdminFarmDetailScreen> {
  bool _isWorking = false;

  Future<void> _addTree(FarmManagerFarm farm) async {
    final formData = await showAdminTreeFormDialog(
      context,
      farmName: farm.name,
      defaultFarmerName: farm.farmerName,
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showAdminNameConfirmationDialog(
      context: context,
      title: 'Confirm New Tree',
      entityLabel: 'tree',
      expectedName: formData.treeId,
      actionLabel: 'Add Tree',
      warning:
          'This will add a tree to ${farm.name}. Type the tree ID to continue.',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).createTree(
            farmId: farm.id,
            farmName: farm.name,
            farmerName: farm.farmerName,
            farmerId: farm.farmerId,
            farmerEmail: farm.farmerEmail,
            data: formData,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tree added successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _editFarm(FarmManagerFarm farm) async {
    final formData = await showAdminFarmFormDialog(
      context,
      initialData: AdminFarmFormData.fromFarm(farm),
    );

    if (formData == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showAdminNameConfirmationDialog(
      context: context,
      title: 'Confirm Farm Update',
      entityLabel: 'farm',
      expectedName: farm.name,
      actionLabel: 'Save Farm',
      warning:
          'This will change the farm record. Type the current farm name to continue.',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).updateFarm(
            farmId: farm.id,
            data: formData,
            linkedTreeDocIds: farm.treeDocIds,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _deleteFarm(FarmManagerFarm farm) async {
    final confirmed = await showAdminNameConfirmationDialog(
      context: context,
      title: 'Delete Farm',
      entityLabel: 'farm',
      expectedName: farm.name,
      actionLabel: 'Delete Farm',
      destructive: true,
      warning: 'This will delete ${farm.name} and ${farm.treeDocIds.length} '
          'linked tree(s), including tree issue records. Type the farm name '
          'to continue.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).deleteFarm(
            farmId: farm.id,
            treeDocIds: farm.treeDocIds,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${farm.name} deleted successfully.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  void _openTreeDetails(String treeDocId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminTreeDetailScreen(treeDocId: treeDocId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(globalFarmOverviewProvider);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Farm Details'),
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load farm details: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (overview) {
          FarmManagerFarm? currentFarm;
          for (final farm in overview.farms) {
            if (farm.id == widget.farmId) {
              currentFarm = farm;
              break;
            }
          }

          if (currentFarm == null) {
            return const Center(
              child: Text('This farm no longer exists.'),
            );
          }

          final sortedTrees = List<Map<String, dynamic>>.from(
            currentFarm.trees,
          )..sort((left, right) {
              final leftId = firstNonEmptyString(
                [left['treeId']],
                fallback: 'Tree',
              ).toLowerCase();
              final rightId = firstNonEmptyString(
                [right['treeId']],
                fallback: 'Tree',
              ).toLowerCase();
              return leftId.compareTo(rightId);
            });

          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade800,
                      Colors.green.shade500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentFarm.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentFarm.location,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: '${currentFarm.totalTrees} trees',
                          color: Colors.white,
                          textColor: Colors.green.shade800,
                        ),
                        _InfoChip(
                          label: '${currentFarm.healthPercent}% healthy',
                          color: Colors.white,
                          textColor: Colors.green.shade800,
                        ),
                        _InfoChip(
                          label: '${currentFarm.alertCount} alerts',
                          color: Colors.white,
                          textColor: Colors.green.shade800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isWorking)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              ResponsiveWrapGrid(
                minChildWidth: 150,
                maxColumns: 2,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _isWorking ? null : () => _editFarm(currentFarm!),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Farm'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isWorking ? null : () => _addTree(currentFarm!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Tree'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isWorking ? null : () => _deleteFarm(currentFarm!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Farm'),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Farm Information',
                children: [
                  _DetailRow(label: 'Location', value: currentFarm.location),
                  _DetailRow(
                    label: 'Area',
                    value: currentFarm.areaAcres <= 0
                        ? 'Not set'
                        : '${currentFarm.areaAcres} acres',
                  ),
                  _DetailRow(
                    label: 'Farm ID',
                    value: _displayFarmId(currentFarm),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Trees in This Farm',
                children: [
                  if (sortedTrees.isEmpty)
                    Text(
                      'No trees have been added to this farm yet.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    ...sortedTrees.map(
                      (tree) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TreeTile(
                          tree: tree,
                          onTap: () {
                            final treeDocId =
                                (tree['_docId'] ?? '').toString().trim();
                            if (treeDocId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This tree is missing a document id.',
                                  ),
                                ),
                              );
                              return;
                            }
                            _openTreeDetails(treeDocId);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String _displayFarmId(FarmManagerFarm farm) {
    final explicitTreeFarmId = firstNonEmptyString(
      farm.trees
          .expand((tree) => [tree['farmId'], tree['assignedFarmId']])
          .toList(),
    );
    if (explicitTreeFarmId.isNotEmpty) {
      return _farmIdOnly(explicitTreeFarmId);
    }

    return _farmIdOnly(farm.id);
  }

  String _farmIdOnly(String value) {
    final parts = value
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'Not set';
    }

    return parts.last;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context, breakpoint: 340);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({
    required this.tree,
    required this.onTap,
  });

  final Map<String, dynamic> tree;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final health = healthLabel(tree['healthStatus']);
    final color = healthColor(health);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBF6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E9DD)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.park_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstNonEmptyString(
                      [tree['treeId']],
                      fallback: 'Tree',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    firstNonEmptyString(
                      [tree['species'], tree['location']],
                      fallback: 'Details unavailable',
                    ),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age ${asInt(tree['treeAge'] ?? tree['age'])} yrs • '
                    'Yield ${asDouble(tree['lastYieldKg'] ?? tree['yieldKg'])} kg',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  health,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

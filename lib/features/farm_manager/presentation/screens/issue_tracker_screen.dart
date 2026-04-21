import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../farm_manager_data.dart';

class IssueTrackerScreen extends StatefulWidget {
  const IssueTrackerScreen({
    super.key,
    this.initialFarmFilter = '',
  });

  final String initialFarmFilter;

  @override
  State<IssueTrackerScreen> createState() => _IssueTrackerScreenState();
}

class _IssueTrackerScreenState extends State<IssueTrackerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _selectedSeverity = 'All';
  Future<List<FarmManagerIssue>>? _scopedIssueFuture;
  String _scopedIssueKey = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _ensureScopedIssueFuture(
    List<Map<String, dynamic>> scopedTrees,
    FarmManagerScope scope,
  ) {
    final ids = scopedTrees
        .map((tree) => (tree['_docId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false)
      ..sort();
    final key = '${scope.managerUid}|${ids.join('|')}';

    if (_scopedIssueKey == key && _scopedIssueFuture != null) {
      return;
    }

    _scopedIssueKey = key;
    _scopedIssueFuture = _loadScopedIssues(scopedTrees, scope);
  }

  Future<List<FarmManagerIssue>> _loadScopedIssues(
    List<Map<String, dynamic>> scopedTrees,
    FarmManagerScope scope,
  ) async {
    if (scopedTrees.isEmpty) {
      try {
        final snapshot =
            await FirebaseFirestore.instance.collectionGroup('issues').get();
        return buildIssueSummaries(
          issueDocs: snapshot.docs,
          scopedTrees: scopedTrees,
          scope: scope,
        );
      } catch (_) {
        return const [];
      }
    }

    final issueGroups = await Future.wait(
      scopedTrees.map((tree) async {
        final treeDocId = (tree['_docId'] ?? '').toString().trim();
        if (treeDocId.isEmpty) {
          return <Map<String, dynamic>>[];
        }

        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('trees')
              .doc(treeDocId)
              .collection('issues')
              .get();

          return snapshot.docs
              .map(
                (doc) => <String, dynamic>{
                  '_docId': doc.id,
                  ...doc.data(),
                },
              )
              .toList(growable: false);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }),
    );

    final issueMaps =
        issueGroups.expand((group) => group).toList(growable: false);

    if (issueMaps.isEmpty) {
      return buildDerivedIssuesFromTrees(scopedTrees);
    }

    return buildIssueSummariesFromMaps(
      issueMaps: issueMaps,
      scopedTrees: scopedTrees,
      scope: scope,
    );
  }

  Widget _buildIssueContent(
    List<FarmManagerIssue> issues, {
    String? helperMessage,
  }) {
    final filteredIssues = issues.where((issue) {
      if (widget.initialFarmFilter.isNotEmpty &&
          issue.farmId != widget.initialFarmFilter &&
          issue.farmLabel.toLowerCase() !=
              widget.initialFarmFilter.toLowerCase()) {
        return false;
      }

      if (_selectedSeverity != 'All' && issue.severity != _selectedSeverity) {
        return false;
      }

      final query = _search.trim().toLowerCase();
      if (query.isEmpty) return true;
      return issue.title.toLowerCase().contains(query) ||
          issue.treeId.toLowerCase().contains(query) ||
          issue.farmLabel.toLowerCase().contains(query) ||
          issue.ownerName.toLowerCase().contains(query) ||
          issue.note.toLowerCase().contains(query);
    }).toList(growable: false);

    final totalCount = issues.length;
    final criticalCount =
        issues.where((issue) => issue.severity == 'Critical').length;
    final monitoringCount =
        issues.where((issue) => issue.severity == 'Monitoring').length;
    final resolvedCount =
        issues.where((issue) => issue.severity == 'Resolved').length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: Colors.green.shade800,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live issue feed',
                style: TextStyle(
                  color: Colors.green.shade100,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Farm manager issue overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TopCard(
                      title: 'Total Issues',
                      count: '$totalCount',
                      subtitle: 'Across managed farms',
                      color: Colors.white,
                      textColor: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TopCard(
                      title: 'Critical',
                      count: '$criticalCount',
                      subtitle: 'Needs attention',
                      color: Colors.red.shade50,
                      textColor: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (helperMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    helperMessage,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _SearchPanel(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    label: 'All',
                    active: _selectedSeverity == 'All',
                    onTap: () {
                      setState(() {
                        _selectedSeverity = 'All';
                      });
                    },
                  ),
                  _FilterChip(
                    label: 'Critical',
                    active: _selectedSeverity == 'Critical',
                    onTap: () {
                      setState(() {
                        _selectedSeverity = 'Critical';
                      });
                    },
                  ),
                  _FilterChip(
                    label: 'Monitoring',
                    active: _selectedSeverity == 'Monitoring',
                    onTap: () {
                      setState(() {
                        _selectedSeverity = 'Monitoring';
                      });
                    },
                  ),
                  _FilterChip(
                    label: 'Resolved',
                    active: _selectedSeverity == 'Resolved',
                    onTap: () {
                      setState(() {
                        _selectedSeverity = 'Resolved';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issue Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ProgressRow(
                      label: 'Critical',
                      color: Colors.red,
                      count: criticalCount,
                      total: totalCount,
                    ),
                    const SizedBox(height: 10),
                    _ProgressRow(
                      label: 'Monitoring',
                      color: Colors.orange,
                      count: monitoringCount,
                      total: totalCount,
                    ),
                    const SizedBox(height: 10),
                    _ProgressRow(
                      label: 'Resolved',
                      color: Colors.green,
                      count: resolvedCount,
                      total: totalCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active Issues Feed',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredIssues.length} items',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredIssues.isEmpty)
                const _EmptyIssueState()
              else
                ...filteredIssues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IssueCard(issue: issue),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Issue Tracker'),
      ),
      body: FutureBuilder<FarmManagerScope>(
        future: loadFarmManagerScope(),
        builder: (context, scopeSnapshot) {
          if (scopeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final scope = scopeSnapshot.data ??
              const FarmManagerScope(
                managerUid: '',
                managerEmail: '',
                managerCode: '',
                linkedFarmerIds: <String>{},
                linkedFarmerEmails: <String>{},
              );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('trees').snapshots(),
            builder: (context, treeSnapshot) {
              if (treeSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (treeSnapshot.hasError) {
                return Center(
                  child:
                      Text('Unable to load tree data: ${treeSnapshot.error}'),
                );
              }

              final treeDocs = treeSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final scopedTrees = buildScopedTrees(treeDocs, scope);

              if (scopedTrees.isNotEmpty) {
                _ensureScopedIssueFuture(scopedTrees, scope);

                return FutureBuilder<List<FarmManagerIssue>>(
                  future: _scopedIssueFuture,
                  builder: (context, scopedIssueSnapshot) {
                    if (scopedIssueSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !scopedIssueSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return _buildIssueContent(
                      scopedIssueSnapshot.data ?? const <FarmManagerIssue>[],
                      helperMessage: scopedIssueSnapshot.hasError
                          ? 'Issue subcollections are not readable for this role, '
                              'so the tracker is showing health-based alerts from '
                              'the managed trees instead.'
                          : null,
                    );
                  },
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('issues')
                    .snapshots(),
                builder: (context, issueSnapshot) {
                  if (issueSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final issueDocs = issueSnapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final issues = buildIssueSummaries(
                    issueDocs: issueDocs,
                    scopedTrees: const <Map<String, dynamic>>[],
                    scope: const FarmManagerScope(
                      managerUid: '',
                      managerEmail: '',
                      managerCode: '',
                      linkedFarmerIds: <String>{},
                      linkedFarmerEmails: <String>{},
                    ),
                  );

                  return _buildIssueContent(
                    issues,
                    helperMessage: issueSnapshot.hasError
                        ? 'Issue details are restricted by Firestore rules for '
                            'this account. No accessible issue records were '
                            'found yet.'
                        : 'Showing the global issue feed because no managed trees '
                            'were matched for this farm manager yet.',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.color,
    required this.textColor,
  });

  final String title;
  final String count;
  final String subtitle;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: textColor.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by tree, farm, owner, or note',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.color,
    required this.count,
    required this.total,
  });

  final String label;
  final Color color;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final FarmManagerIssue issue;

  @override
  Widget build(BuildContext context) {
    final severityColor = issueSeverityColor(issue.severity);
    final createdAtLabel = issue.createdAt == null
        ? 'Time unavailable'
        : DateFormat('dd MMM, hh:mm a').format(issue.createdAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              issue.severity == 'Resolved'
                  ? Icons.check_circle_outline
                  : issue.severity == 'Critical'
                      ? Icons.warning_amber_rounded
                      : Icons.timelapse_outlined,
              color: severityColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        issue.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        issue.severity,
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${issue.farmLabel}  •  ${issue.treeId}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.person_outline,
                      label: issue.ownerName,
                    ),
                    _MetaPill(
                      icon: Icons.favorite_outline,
                      label: issue.healthLabel,
                    ),
                    _MetaPill(
                      icon: Icons.info_outline,
                      label: issueStatusLabel(issue.status),
                    ),
                    if (issue.hasImage)
                      const _MetaPill(
                        icon: Icons.photo_library_outlined,
                        label: 'Image attached',
                      ),
                  ],
                ),
                if (issue.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    issue.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  createdAtLabel,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyIssueState extends StatelessWidget {
  const _EmptyIssueState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching issues found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When farmers report tree problems, they will appear here with live status information.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

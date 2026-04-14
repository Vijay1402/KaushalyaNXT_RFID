import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';

final activityLogProvider = FutureProvider.autoDispose<
    ({List<Map<String, dynamic>> scans, List<Map<String, dynamic>> issues})>(
  (ref) async {
    final user = ref.read(authServiceProvider).getCurrentUser();
    if (user == null) {
      return (
        scans: <Map<String, dynamic>>[],
        issues: <Map<String, dynamic>>[],
      );
    }

    final cache = LocalCacheService();
    final scans = List<Map<String, dynamic>>.from(
      await cache.getScanHistory(user.uid),
    );
    final issues = List<Map<String, dynamic>>.from(
      await cache.getIssueHistory(user.uid),
    );

    if (scans.isEmpty) {
      scans.addAll(await cache.getWrittenTags(user.uid));
    }

    scans.sort(
      (a, b) => _sortNewest(
        (a['savedAt'] ?? a['savedAtLocal'] ?? '').toString(),
        (b['savedAt'] ?? b['savedAtLocal'] ?? '').toString(),
      ),
    );
    issues.sort(
      (a, b) => _sortNewest(
        (a['createdAtLocal'] ?? a['syncedAtLocal'] ?? '').toString(),
        (b['createdAtLocal'] ?? b['syncedAtLocal'] ?? '').toString(),
      ),
    );

    return (scans: scans, issues: issues);
  },
);

int _sortNewest(String left, String right) {
  final leftDate = DateTime.tryParse(left);
  final rightDate = DateTime.tryParse(right);
  if (leftDate == null && rightDate == null) return 0;
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  return rightDate.compareTo(leftDate);
}

enum _ActivityFilter {
  all,
  scans,
  issues,
}

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  _ActivityFilter _selectedFilter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityLogProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: activityAsync.when(
        data: (activity) {
          final scans = activity.scans;
          final issues = activity.issues;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilterBar(scans.length, issues.length),
              const SizedBox(height: 18),
              if (_selectedFilter != _ActivityFilter.issues) ...[
                _sectionHeader(
                  title: 'Scan History',
                  count: scans.length,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 10),
                if (scans.isEmpty)
                  const _EmptyCard(message: 'No scan history available yet.')
                else
                  ...scans.map(_ScanLogCard.new),
                if (_selectedFilter == _ActivityFilter.all)
                  const SizedBox(height: 20),
              ],
              if (_selectedFilter != _ActivityFilter.scans) ...[
                _sectionHeader(
                  title: 'Farmer Issues',
                  count: issues.length,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 10),
                if (issues.isEmpty)
                  const _EmptyCard(message: 'No issue reports available yet.')
                else
                  ...issues.map(_IssueLogCard.new),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Unable to load activity log: $error'),
        ),
      ),
    );
  }

  Widget _buildFilterBar(int scanCount, int issueCount) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _filterButton(
          label: 'All',
          count: scanCount + issueCount,
          filter: _ActivityFilter.all,
          color: Colors.blue.shade700,
        ),
        _filterButton(
          label: 'Scan History',
          count: scanCount,
          filter: _ActivityFilter.scans,
          color: Colors.green.shade700,
        ),
        _filterButton(
          label: 'Issues',
          count: issueCount,
          filter: _ActivityFilter.issues,
          color: Colors.orange.shade700,
        ),
      ],
    );
  }

  Widget _filterButton({
    required String label,
    required int count,
    required _ActivityFilter filter,
    required Color color,
  }) {
    final selected = _selectedFilter == filter;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}

class _ScanLogCard extends StatelessWidget {
  final Map<String, dynamic> scan;

  const _ScanLogCard(this.scan);

  @override
  Widget build(BuildContext context) {
    final lastScan = _formatIso(scan['savedAt'] ?? scan['savedAtLocal']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (scan['treeId'] ?? 'Unknown Tree').toString(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _logRow('Last Scan', lastScan),
        ],
      ),
    );
  }
}

class _IssueLogCard extends StatelessWidget {
  final Map<String, dynamic> issue;

  const _IssueLogCard(this.issue);

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatIso(
      issue['createdAtLocal'] ?? issue['syncedAtLocal'],
    );
    final synced = (issue['imageUrl'] ?? '').toString().trim().isNotEmpty ||
        (issue['syncedAtLocal'] ?? '').toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (issue['treeId'] ?? 'Unknown Tree').toString(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _logRow('Species', (issue['species'] ?? '-').toString()),
          _logRow('Health', (issue['healthStatus'] ?? '-').toString()),
          _logRow(
            'Notes',
            (issue['note'] ?? '').toString().trim().isEmpty
                ? '-'
                : (issue['note'] ?? '-').toString(),
          ),
          _logRow('Status', synced ? 'Synced' : 'Saved locally'),
          _logRow('Raised', createdAt),
        ],
      ),
    );
  }
}

Widget _logRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _formatIso(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
}

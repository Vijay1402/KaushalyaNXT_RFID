import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../tree_details/tree_controller.dart';

final _pendingTreeSyncCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authServiceProvider).getCurrentUser();
  if (user == null) return 0;
  final items = await LocalCacheService().getPendingTreeSyncs(user.uid);
  return items.length;
});

class FarmerDashboard extends ConsumerWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final treesAsync = ref.watch(treesProvider);
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    final pendingSyncAsync = ref.watch(_pendingTreeSyncCountProvider);
    final userName =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Farmer';
    final stats = treesAsync.when(
      data: (trees) {
        final uniqueTrees = _dedupeTrees(trees);
        final total = uniqueTrees.length;
        final healthy = uniqueTrees.where((tree) {
          return _statusLabel(tree['healthStatus']) == 'Healthy';
        }).length;
        final needAttention = uniqueTrees.where((tree) {
          return _statusLabel(tree['healthStatus']) == 'NeedsAttention';
        }).length;

        return (
          total: total.toString(),
          healthy: healthy.toString(),
          needAttention: needAttention.toString(),
        );
      },
      loading: () => (total: '...', healthy: '...', needAttention: '...'),
      error: (_, __) => (total: '-', healthy: '-', needAttention: '-'),
    );

    return Scaffold(
      backgroundColor: Colors.grey[200],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => context.push('/scan'),
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navItem(Icons.home, 'Home', isActive: true),
                InkWell(
                  onTap: () => context.push('/my-trees'),
                  child: _navItem(Icons.park, 'My Trees'),
                ),
                const SizedBox(width: 40),
                InkWell(
                  onTap: () => context.push('/report'),
                  child: _navItem(Icons.insert_chart, 'Report'),
                ),
                InkWell(
                  onTap: () => context.push('/profile'),
                  child: _navItem(Icons.person, 'Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.agriculture, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Namaste, $userName!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const NotificationSheet(),
                        );
                      },
                      icon: const Icon(Icons.notifications),
                      tooltip: 'Notifications',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SyncDetailsSheet(
                        isOnline: isOnline,
                        pendingCount: pendingSyncAsync.valueOrNull ?? 0,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFFDFF5E1)
                          : const Color(0xFFFFE0E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SYNC STATUS PANEL'),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 5,
                                  backgroundColor:
                                      isOnline ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 5),
                                Text(isOnline ? 'ONLINE' : 'OFFLINE'),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.sync),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pendingSyncAsync.when(
                                  data: (count) {
                                    if (isOnline && count == 0) {
                                      return 'Tag <-> Cloud Sync: ACTIVE\nAll local changes are synced.';
                                    }
                                    if (isOnline) {
                                      return 'Tag <-> Cloud Sync: ACTIVE\n$count item(s) are finishing sync now.';
                                    }
                                    return 'Working offline\n$count item(s) saved locally and waiting for sync.';
                                  },
                                  loading: () => 'Checking sync status...',
                                  error: (_, __) =>
                                      'Sync status is unavailable right now.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatCard(
                      title: 'My Trees',
                      value: stats.total,
                      icon: Icons.park,
                      onTap: () => context.push('/my-trees'),
                    ),
                    _StatCard(
                      title: 'Healthy',
                      value: stats.healthy,
                      icon: Icons.favorite,
                      onTap: () => context.push('/my-trees?filter=healthy'),
                    ),
                    _StatCard(
                      title: 'Need Attention',
                      value: stats.needAttention,
                      icon: Icons.warning_amber_rounded,
                      warning: true,
                      onTap: () => context.push('/my-trees?filter=attention'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "TODAY'S TASKS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _TaskCard(
                      title: 'Scan a nearby tree tag',
                      subtitle: 'Write or read RFID data for field work',
                      button: 'SCAN NOW',
                      onPressed: () => context.push('/scan'),
                    ),
                    _TaskCard(
                      title: 'Review your tree records',
                      subtitle: 'Open My Trees and check sync status',
                      button: 'OPEN TREES',
                      warning: (pendingSyncAsync.valueOrNull ?? 0) > 0,
                      onPressed: () => context.push('/my-trees'),
                    ),
                    _TaskCard(
                      title: 'Update farmer profile',
                      subtitle: 'Edit contact details and reset password',
                      button: 'OPEN PROFILE',
                      onPressed: () => context.push('/profile'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? Colors.green : Colors.black),
        const SizedBox(height: 2),
        Text(label),
      ],
    );
  }

  List<Map<String, dynamic>> _dedupeTrees(List<Map<String, dynamic>> trees) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final tree in trees) {
      final docId = (tree[treeDocIdField] ?? '').toString().trim();
      final treeId = (tree['treeId'] ?? '').toString().trim();
      final key = docId.isNotEmpty ? docId : treeId;
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(tree);
    }

    return result;
  }

  String _statusLabel(dynamic status) {
    switch ((status ?? '').toString()) {
      case '0':
        return 'Healthy';
      case '1':
        return 'NeedsAttention';
      case '2':
        return 'AtRisk';
      default:
        return 'Healthy';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool warning;
  final VoidCallback? onTap;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.warning = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 105,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFEED9B7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: warning ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              icon,
              size: 34,
              color: warning ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class SyncDetailsSheet extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const SyncDetailsSheet({
    super.key,
    required this.isOnline,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _sheetRow(
            'Status',
            isOnline ? 'Online' : 'Offline',
            color: isOnline ? Colors.green : Colors.orange,
          ),
          _sheetRow('Pending Uploads', '$pendingCount item(s)'),
          _sheetRow(
            'Mode',
            isOnline ? 'Cloud sync active' : 'Local storage only',
          ),
          _sheetRow(
            'Next Action',
            isOnline
                ? 'Pending data will sync automatically'
                : 'Reconnect internet to sync pending items',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetRow(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView(
              children: const [
                _NotificationSection(
                  title: 'Weather Alerts',
                  items: [
                    NotificationItem('Rain expected today', '2 mins ago'),
                    NotificationItem('High temperature warning', '1 hour ago'),
                  ],
                ),
                _NotificationSection(
                  title: 'Reminders',
                  items: [
                    NotificationItem('Scan pending trees today', '10 mins ago'),
                    NotificationItem('Review issue reports', '30 mins ago'),
                  ],
                ),
                _NotificationSection(
                  title: 'System Updates',
                  items: [
                    NotificationItem(
                        'Offline data will sync automatically', 'Just now'),
                    NotificationItem('Profile changes saved', '2 hours ago'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  final String title;
  final List<NotificationItem> items;

  const _NotificationSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _NotificationTile(item: item)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class NotificationItem {
  final String message;
  final String time;

  const NotificationItem(this.message, this.time);
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(item.message)),
          Text(
            item.time,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String button;
  final bool warning;
  final VoidCallback? onPressed;

  const _TaskCard({
    required this.title,
    required this.subtitle,
    required this.button,
    this.warning = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warning ? Colors.orange : Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Task: $subtitle'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onPressed,
              child: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}

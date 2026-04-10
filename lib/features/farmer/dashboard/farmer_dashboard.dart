import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../tree_details/tree_controller.dart';

class FarmerDashboard extends ConsumerWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final treesAsync = ref.watch(treesProvider);
    final userName =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Farmer';
    final stats = treesAsync.when(
      data: (trees) {
        final total = trees.length;
        final healthy = trees.where((tree) {
          final health = (tree['healthStatus'] ?? '').toString();
          return health == '0';
        }).length;
        final needAttention = trees.where((tree) {
          final health = (tree['healthStatus'] ?? '').toString();
          return health == '1';
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

      /// FLOATING BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          context.push('/scan');
        },
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// BOTTOM NAV
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(Icons.home, "Home", isActive: true),
              InkWell(
                onTap: () => context.push('/my-trees'),
                child: _navItem(Icons.park, "My Trees"),
              ),
              const SizedBox(width: 40),
              InkWell(
                onTap: () => context.push('/report'),
                child: _navItem(Icons.insert_chart, "Report"),
              ),
              InkWell(
                onTap: () => context.push('/profile'),
                child: _navItem(Icons.person, "Profile"),
              ),
            ],
          ),
        ),
      ),

      /// BODY
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.agriculture, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Namaste, $userName!",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.notifications),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// SYNC PANEL
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF5E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("SYNC STATUS PANEL"),
                          Row(
                            children: [
                              CircleAvatar(
                                  radius: 5, backgroundColor: Colors.green),
                              SizedBox(width: 5),
                              Text("ONLINE"),
                            ],
                          ),
                        ],
                      ),
                      Divider(),
                      Row(
                        children: [
                          Icon(Icons.sync),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tag ↔ Cloud Sync: ACTIVE\nLast Sync: 2 hours ago",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔥 CLICKABLE STATS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatCard(
                      title: "My Trees",
                      value: stats.total,
                      onTap: () {
                        context.push('/my-trees');
                      },
                    ),
                    _StatCard(
                      title: "Healthy",
                      value: stats.healthy,
                      onTap: () {
                        context.push('/my-trees?filter=healthy');
                      },
                    ),
                    _StatCard(
                      title: "Need Attention",
                      value: stats.needAttention,
                      warning: true,
                      onTap: () {
                        context.push('/my-trees?filter=attention');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "TODAY’S TASKS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                /// ✅ FIXED LIST (NO CONST ERROR)
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _TaskCard(
                      title: "Scan Tree #14 - jackfruit #A001",
                      subtitle: "Verify fruit growth stage",
                      button: "SCAN NOW",
                    ),
                    _TaskCard(
                      title: "Check Tree #09 - Jackfruit #B005",
                      subtitle: "Inspect for pest activity",
                      button: "VIEW DETAILS",
                      warning: true,
                    ),
                    _TaskCard(
                      title: "Scan Tree #09 - jackfruit #B005",
                      subtitle: "Verify fruit growth stage",
                      button: "SCAN NOW",
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
}

/// 🔥 CLICKABLE STAT CARD
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool warning;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TASK CARD
class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String button;
  final bool warning;

  const _TaskCard({
    required this.title,
    required this.subtitle,
    required this.button,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("Task: $subtitle"),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              child: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}

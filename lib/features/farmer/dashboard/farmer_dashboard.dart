import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FarmerDashboard extends StatelessWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      /// 🔵 FLOATING BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {},
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// 🔻 BOTTOM NAV (FIXED OVERFLOW)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(Icons.home, "Home", isActive: true),

              InkWell(
                onTap: () => context.go('/my-trees'),
                child: _navItem(Icons.park, "My Trees"),
              ),

              const SizedBox(width: 40),

              _navItem(Icons.insert_chart, "Report"),
              _navItem(Icons.person, "Profile"),
            ],
          ),
        ),
      ),

      /// 🔥 BODY (SCROLL FIXED)
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 🔥 FIX
              children: [
                /// HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.agriculture, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Namaste, Farmer!",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.notifications),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 🔥 FIX
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("SYNC STATUS PANEL"),
                          Row(
                            children: [
                              CircleAvatar(radius: 5, backgroundColor: Colors.green),
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

                /// STATS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _StatCard(title: "My Trees", value: "24"),
                    _StatCard(title: "Healthy", value: "22"),
                    _StatCard(title: "Need Attention", value: "2", warning: true),
                  ],
                ),

                const SizedBox(height: 20),

                /// TITLE
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "TODAY’S TASKS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                /// TASK LIST (FIXED)
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
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

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔻 NAV ITEM (FIXED OVERFLOW)
  Widget _navItem(IconData icon, String label, {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? Colors.green : Colors.black),
        const SizedBox(height: 2), // 🔥 FIX
        Text(label),
      ],
    );
  }
}

/// 📊 STAT CARD (FIXED)
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool warning;

  const _StatCard({
    required this.title,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFEED9B7) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔥 FIX
        children: [
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// 📋 TASK CARD (FIXED)
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
        mainAxisSize: MainAxisSize.min, // 🔥 FIX
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("Task: $subtitle"),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: warning ? Colors.orange : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {},
              child: Text(button),
            ),
          ),
        ],
      ),
    );
  }
}
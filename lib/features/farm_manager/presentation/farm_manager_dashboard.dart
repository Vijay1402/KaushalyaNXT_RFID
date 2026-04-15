import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/providers/auth_provider.dart';
import 'screens/farm_list_screen.dart';

class FarmManagerDashboard extends ConsumerStatefulWidget {
  const FarmManagerDashboard({super.key});

  @override
  ConsumerState<FarmManagerDashboard> createState() =>
      _FarmManagerDashboardState();
}

class _FarmManagerDashboardState
    extends ConsumerState<FarmManagerDashboard> {

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final name =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name : "Manager";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _header(name),
              const SizedBox(height: 14),

              /// FARMS + TREES
              Row(
                children: [
                  Expanded(child: _farmsCard()),
                  const SizedBox(width: 10),
                  Expanded(child: _treesCard()),
                ],
              ),

              const SizedBox(height: 14),

              /// HEALTH
              _healthSection(),

              const SizedBox(height: 14),

              _issueTracker(),

              const SizedBox(height: 14),

              /// ISSUES
              Row(
                children: [
                  Expanded(child: _issuesCard()),
                  const SizedBox(width: 10),
                  Expanded(child: _criticalCard()),
                ],
              ),

              const SizedBox(height: 14),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Global Alerts Feed",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Recently")
                ],
              ),

              const SizedBox(height: 10),

              _alertsList(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _navBar(),
    );
  }

  /// ================= HEADER =================
  Widget _header(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Namaste,\nManager $name!",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications, color: Colors.white),
          )
        ],
      ),
    );
  }

  /// ================= FARMS =================
  Widget _farmsCard() {
    return _infoCard(
      "Total Managed Farms",
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('farms').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Text("...");
          return Text("${snapshot.data!.docs.length}",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold));
        },
      ),
      () => context.push('/farms'),
    );
  }

  /// ================= TREES =================
  Widget _treesCard() {
    return _infoCard(
      "Total Trees",
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('trees').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Text("...");
          return Text("${snapshot.data!.docs.length}",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold));
        },
      ),
      () => context.push('/trees'),
    );
  }

  /// ================= HEALTH =================
 Widget _healthSection() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('trees').snapshots(),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return _sectionCard(
          child: Center(child: Text("Loading...")),
        );
      }

      int total = snapshot.data!.docs.length;
      int healthy = 0;
      int unhealthy = 0;

      for (var doc in snapshot.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String status = (data['status'] ?? 'healthy').toLowerCase();

        if (status == 'healthy') {
          healthy++;
        } else {
          unhealthy++;
        }
      }

      double percentage = total == 0 ? 0 : (healthy / total) * 100;

      return _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text("Health Summary",
                style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 10),

            /// TOP COUNTS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _dot(Colors.green),
                    const SizedBox(width: 6),
                    Text("Healthy: $healthy"),
                  ],
                ),
                Row(
                  children: [
                    _dot(Colors.red),
                    const SizedBox(width: 6),
                    Text("Unhealthy: $unhealthy"),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [

                /// BIG PERCENT BOX (MAIN FIX)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${percentage.toStringAsFixed(0)}%",
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text("Healthy"),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                /// VISUAL BARS (BASED ON REAL DATA)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _bar(
                        total == 0 ? 0 : (healthy / total) * 60,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _bar(
                        total == 0 ? 0 : (unhealthy / total) * 60,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  /// ================= ISSUES =================
  Widget _issuesCard() {
    return _infoCard(
      "Total Issues",
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('issues').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Text("...");
          return Text("${snapshot.data!.docs.length}",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold));
        },
      ),
      () => context.push('/issues'),
    );
  }

  Widget _criticalCard() {
    return _infoCard(
      "Critical",
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('issues')
            .where('type', isEqualTo: 'critical')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Text("...");
          return Text("${snapshot.data!.docs.length}",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold));
        },
      ),
      () => context.push('/critical'),
    );
  }

  /// ================= ALERTS =================
  Widget _alertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('issues').snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No alerts available");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _alertCard(data['message'] ?? "No message");
          }).toList(),
        );
      },
    );
  }

  /// ================= COMMON =================
  Widget _infoCard(String title, Widget value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            value,
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _issueTracker() {
    return InkWell(
      onTap: () => context.push('/issues'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: const [
            Icon(Icons.grid_view, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Issue Tracker\nAll Managed Farms",
                style: TextStyle(color: Colors.white),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)
          ],
        ),
      ),
    );
  }

  Widget _alertCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text("Critical Alert\n$message")),
        ],
      ),
    );
  }

  /// ================= NAV =================
  Widget _navBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, "Home", 0),
          _navItem(Icons.agriculture, "My Farms", 1),

          GestureDetector(
            onTap: () => context.push('/scan'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code, color: Colors.white),
            ),
          ),

          _navItem(Icons.bar_chart, "Analytics", 3),
          _navItem(Icons.person, "Profile", 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);

        if (index == 0) context.go('/home');
        if (index == 1) context.go('/farms');
        if (index == 3) context.go('/analytics');
        if (index == 4) context.go('/profile');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: selectedIndex == index ? Colors.green : Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selectedIndex == index
                      ? Colors.green
                      : Colors.grey)),
        ],
      ),
    );
  }
}
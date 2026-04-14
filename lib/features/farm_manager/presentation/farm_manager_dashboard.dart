import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../auth/providers/auth_provider.dart';

class FarmManagerDashboard extends ConsumerStatefulWidget {
  const FarmManagerDashboard({super.key});

  @override
  ConsumerState<FarmManagerDashboard> createState() =>
      _FarmManagerDashboardState();
}

class _FarmManagerDashboardState
    extends ConsumerState<FarmManagerDashboard> {

  int currentIndex = 0;

  /// 🔥 BAR HEIGHT CALCULATOR
  double getBarHeight(int value, int max) {
    if (max == 0) return 20;
    return (value / max) * 80 + 10;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final name = user?.name ?? "Manager";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      body: SafeArea(
        child: StreamBuilder(
          stream: FirebaseFirestore.instance.collection('farms').snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> farmSnap) {

            if (!farmSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            int totalFarms = farmSnap.data!.docs.length;
            int totalTrees = 0;
            int healthy = 0;
            int critical = 0;

            for (var doc in farmSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              totalTrees += (data['treesCount'] ?? 0) as int;
              healthy += (data['healthyCount'] ?? 0) as int;
              critical += (data['criticalCount'] ?? 0) as int;
            }

            /// 🔥 LOW CALCULATION
            int low = totalTrees - (healthy + critical);
            if (low < 0) low = 0;

            /// 🔥 MAX VALUE FOR GRAPH
            int maxValue =
                [low, healthy, critical].reduce((a, b) => a > b ? a : b);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Namaste,\nManager $name!",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.notifications, color: Colors.white)
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// TOP CARDS
                  Row(
                    children: [
                      Expanded(child: _card("Total Farms", "$totalFarms")),
                      const SizedBox(width: 10),
                      Expanded(child: _card("Total Trees", "$totalTrees")),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// HEALTH SUMMARY
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _box(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Text("Healthy Summary",
                            style: TextStyle(fontWeight: FontWeight.bold)),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                    radius: 6, backgroundColor: Colors.red),
                                const SizedBox(width: 6),
                                Text("Critical: $critical")
                              ],
                            ),
                            Row(
                              children: [
                                const CircleAvatar(
                                    radius: 6,
                                    backgroundColor: Colors.green),
                                const SizedBox(width: 6),
                                Text("Good: $healthy")
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [

                            /// 🔥 GAUGE
                            Expanded(
                              child: SizedBox(
                                height: 120,
                                child: SfRadialGauge(
                                  axes: [
                                    RadialAxis(
                                      minimum: 0,
                                      maximum:
                                          maxValue == 0 ? 100 : maxValue.toDouble(),
                                      showLabels: false,
                                      showTicks: false,
                                      startAngle: 180,
                                      endAngle: 0,
                                      axisLineStyle:
                                          const AxisLineStyle(thickness: 12),
                                      pointers: [
                                        RangePointer(
                                          value: healthy.toDouble(),
                                          width: 12,
                                          color: Colors.green,
                                        )
                                      ],
                                      annotations: [
                                        GaugeAnnotation(
                                          widget: Text(
                                            "$healthy\nGood",
                                            textAlign: TextAlign.center,
                                          ),
                                          angle: 90,
                                          positionFactor: 0.1,
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),

                            /// 🔥 DYNAMIC BAR CHART
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _bar(getBarHeight(low, maxValue),
                                      Colors.brown, "Low"),
                                  _bar(getBarHeight(healthy, maxValue),
                                      Colors.green, "Good"),
                                  _bar(getBarHeight(critical, maxValue),
                                      Colors.red, "High"),
                                ],
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// ISSUE TRACKER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.grid_view, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Issue Tracker\nAll Managed Farms",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.white)
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// ISSUE STATS
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('issues')
                        .snapshots(),
                    builder:
                        (context, AsyncSnapshot<QuerySnapshot> issueSnap) {

                      int totalIssues =
                          issueSnap.hasData ? issueSnap.data!.docs.length : 0;

                      return Row(
                        children: [
                          Expanded(
                              child: _card("Total Issues", "$totalIssues")),
                          const SizedBox(width: 10),
                          Expanded(child: _card("Critical", "$critical")),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  /// ALERTS
                  const Text("Global Alerts Feed",
                      style: TextStyle(fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('alerts')
                        .snapshots(),
                    builder:
                        (context, AsyncSnapshot<QuerySnapshot> alertSnap) {

                      if (!alertSnap.hasData) {
                        return const CircularProgressIndicator();
                      }

                      return Column(
                        children: alertSnap.data!.docs.map((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning,
                                    color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "${data['title']}\n${data['message']}",
                                    style:
                                        const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const Icon(Icons.close)
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),

      /// NAVBAR
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, "Home"),
              _navItem(Icons.agriculture, "My Farms"),
              const SizedBox(width: 40),
              _navItem(Icons.analytics, "Analytics"),
              _navItem(Icons.person, "Profile"),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        onPressed: () {},
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _card(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: height,
          width: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(label)
      ],
    );
  }

  Widget _navItem(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        Text(label, style: const TextStyle(fontSize: 11))
      ],
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 5)
      ],
    );
  }
}
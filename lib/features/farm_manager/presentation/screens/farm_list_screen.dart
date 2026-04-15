import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmListScreen extends StatelessWidget {
  const FarmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "All Farms",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications, color: Colors.green),
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            /// SEARCH + FILTER
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.search),
                        hintText: "Search farms...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {},
                  child: const Text("FILTER"),
                )
              ],
            ),

            const SizedBox(height: 12),

            /// 🔥 SYNC PANEL WITH BUTTON
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sync')
                  .doc('status')
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("Loading sync status..."),
                  );
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};

                final isOnline = data['isOnline'] ?? false;
                final lastSync = data['lastSync'] ?? "N/A";
                final status = data['status'] ?? "UNKNOWN";

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Column(
                    children: [

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("🌳 SYNC STATUS PANEL",
                              style: TextStyle(fontWeight: FontWeight.bold)),

                          Text(
                            isOnline ? "✅ ONLINE" : "❌ OFFLINE",
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Tag ↔ Cloud Sync: $status\nLast Sync: $lastSync",
                      ),

                      const SizedBox(height: 12),

                      /// 🔥 SYNC BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isOnline ? Colors.green : Colors.grey,
                          ),
                          onPressed: isOnline
                              ? () async {
                                  await FirebaseFirestore.instance
                                      .collection('sync')
                                      .doc('status')
                                      .update({
                                    'lastSync': 'Just now',
                                    'status': 'ACTIVE',
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Sync completed ✅"),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.sync),
                          label: const Text("SYNC NOW"),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            /// SUMMARY CARDS
            Row(
              children: [
                Expanded(child: _summaryCard("Total Farms", _totalFarms())),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard("Healthy %", _healthyPercent())),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _summaryCard("Total Trees", _totalTrees())),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard("UnHealthy", _unhealthyCount())),
              ],
            ),

            const SizedBox(height: 12),

            /// 🔥 FARM LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('farms')
                    .snapshots(),
                builder: (context, snapshot) {

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No farms available"));
                  }

                  final farms = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: farms.length,
                    itemBuilder: (context, index) {

                      final data =
                          farms[index].data() as Map<String, dynamic>;

                      final name = data['name'] ?? "No Name";
                      final trees = data['trees']?.toString() ?? "0";
                      final healthy = data['healthy'] ?? 0;
                      final alerts = data['alerts'] ?? 0;
                      final image = data['image'];

                      String healthText = "$healthy%";
                      String alertText =
                          alerts == 0 ? "No Alerts" : "$alerts Alerts";

                      return _farmCard(
                        context,
                        name,
                        trees,
                        healthText,
                        alertText,
                        image,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= SUMMARY =================

  Widget _totalFarms() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        return Text("${snapshot.data!.docs.length}",
            style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }

  Widget _totalTrees() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        int total = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          total += (data['trees'] ?? 0) as int;
        }
        return Text("$total",
            style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }

  Widget _healthyPercent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        int total = snapshot.data!.docs.length;
        int sum = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          sum += (data['healthy'] ?? 0) as int;
        }
        double avg = total == 0 ? 0 : sum / total;
        return Text("${avg.toStringAsFixed(0)}%",
            style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }

  Widget _unhealthyCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("...");
        int count = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int healthy = data['healthy'] ?? 0;
          if (healthy < 80) count++;
        }
        return Text("$count",
            style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }

  /// ================= UI =================

  Widget _summaryCard(String title, Widget value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 6),
          value,
        ],
      ),
    );
  }

  Widget _farmCard(
    BuildContext context,
    String name,
    String trees,
    String health,
    String alert,
    String? imageUrl,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [

          /// IMAGE
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: imageUrl != null
                    ? NetworkImage(imageUrl)
                    : const AssetImage('assets/farm.jpg') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 10),

          /// DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.park, size: 16),
                    const SizedBox(width: 4),
                    Text(trees),
                    const SizedBox(width: 12),
                    const Icon(Icons.eco, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(health),
                  ],
                ),

                const SizedBox(height: 6),

                Text(alert,
                    style: TextStyle(
                        color: alert == "No Alerts"
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12)),

                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      context.push('/tree-details');
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text("View Details"),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
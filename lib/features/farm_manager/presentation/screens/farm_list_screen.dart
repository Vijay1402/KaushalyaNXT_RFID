import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FarmListScreen extends StatelessWidget {
  const FarmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () {
            context.go('/farm-manager/home');
          },
        ),
        title: const Text(
          "All Farms",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.green),
            onPressed: () {},
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            /// SEARCH
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Search farms...",
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// SYNC PANEL (UNCHANGED)
            StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              initialData: const [ConnectivityResult.mobile],
              builder: (context, connectivitySnapshot) {

                final results = connectivitySnapshot.data ?? [];
                final isOnline =
                    results.isNotEmpty &&
                    results.first != ConnectivityResult.none;

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sync')
                      .doc('status')
                      .snapshots(),
                  builder: (context, snapshot) {

                    final data =
                        snapshot.data?.data() as Map<String, dynamic>? ?? {};

                    final status = data['status'] ?? "NO DATA";
                    final lastSync = data['lastSync'] ?? "N/A";

                    return GestureDetector(
                      onTap: () {
                        _showSyncDetails(
                            context, isOnline, status, lastSync);
                      },
                      child: Container(
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
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.park,
                                        color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      "SYNC STATUS PANEL",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      isOnline
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isOnline
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOnline
                                          ? "ONLINE"
                                          : "OFFLINE",
                                      style: TextStyle(
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Tag ↔ Cloud Sync: $status\nLast Sync: $lastSync",
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            /// ✅ SUMMARY (ONLY MADE CLICKABLE)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      print("Total Farms clicked");
                    },
                    child: _summaryCard(Icons.agriculture, "Total Farms", "18"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      print("Avg Health clicked");
                    },
                    child: _summaryCard(Icons.eco, "Avg Health", "82%"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      print("Total Trees clicked");
                    },
                    child: _summaryCard(Icons.park, "Total Trees", "12,450"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      print("Farmers clicked");
                    },
                    child: _summaryCard(Icons.warning, "Farmers", "5"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// FARM LIST (UNCHANGED)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('farms')
                    .snapshots(),
                builder: (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final farms = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: farms.length,
                    itemBuilder: (context, index) {

                      final data =
                          farms[index].data() as Map<String, dynamic>;

                      return _farmCard(
                      context,
                          farms[index].id, // ✅ ADD THIS (VERY IMPORTANT)
                          data['name'] ?? "No Name",
                          data['trees'] ?? 0,
                          data['healthy'] ?? 0,
                          data['alerts'] ?? 0,
                            data['image'],
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

  void _showSyncDetails(
      BuildContext context,
      bool isOnline,
      String status,
      String lastSync) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isOnline ? "ONLINE" : "OFFLINE"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Sync: $status"),
            Text("Last Sync: $lastSync"),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
      IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(height: 5),
          Text(title),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// FARM CARD (UNCHANGED)
 Widget _farmCard(
  BuildContext context,
  String farmId, // ✅ ADD THIS
  String name,
  int trees,
  int health,
  int alerts,
  String? imageUrl,
) {
    return GestureDetector(
  onTap: () {
    context.push('/farm-details', extra: farmId);
  },
  child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [

          Row(
            children: [

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        height: 70, width: 90, fit: BoxFit.cover)
                    : Image.asset('assets/farm.jpg',
                        height: 70, width: 90, fit: BoxFit.cover),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.park, size: 16),
                        Text(" $trees"),
                        const SizedBox(width: 10),
                        const Icon(Icons.eco,
                            size: 16, color: Colors.green),
                        Text(" $health%"),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,
                      child: alerts > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  "$alerts Alerts",
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ],
                            )
                          : const Text("No Alerts",
                              style: TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Row(
                children: [
                  const Icon(Icons.park, size: 16),
                  Text(" $trees"),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  Text(" $health%"),
                ],
              ),

              ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: null, // ✅ DISABLED
                icon: const Icon(Icons.remove_red_eye,
                    size: 16, color: Colors.white),
                label: const Text(
                  "View Details",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );  
  }
}
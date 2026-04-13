import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/services/sync_service.dart';

class FarmerDashboard extends StatelessWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
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

      /// ✅ FIXED OVERFLOW
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
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
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc('user1')
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const Text("Namaste!");
                            }

                            final data = snapshot.data!.data() as Map<String, dynamic>?;

                            final name = data?['name'] ?? "Farmer";

                            return Text(
                              "Namaste, $name!",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const NotificationSheet(),
                            );
                          },
                          child: const Icon(Icons.notifications),
                        ),
                        
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// 🔥 SYNC PANEL (FIXED)
                StreamBuilder<DocumentSnapshot>(
                  stream: SyncService().getSyncStatus(),
                  builder: (context, snapshot) {
                    return FutureBuilder<List<ConnectivityResult>>(
                      future: Connectivity().checkConnectivity(),
                      builder: (context, AsyncSnapshot<List<ConnectivityResult>> connSnapshot) {
                        bool isOnline = connSnapshot.data
                                ?.any((item) => item != ConnectivityResult.none) ??
                            false;

                        String lastSync = "Never";

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;

                          if (data["lastSync"] != null) {
                            final time =
                                (data["lastSync"] as Timestamp).toDate();
                            lastSync = "${time.hour}:${time.minute}";
                          }
                        }

                        return InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => SyncDetailsSheet(
                                status: isOnline ? "online" : "offline",
                                lastSync: lastSync,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("SYNC STATUS PANEL"),
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 5,
                                          backgroundColor: isOnline
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(isOnline
                                            ? "ONLINE"
                                            : "OFFLINE"),
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
                                      child: Text("Last Sync: $lastSync"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                /// STATS
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('trees').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final trees = snapshot.data!.docs;

                    int total = trees.length;

                    int healthy = trees.where((t) {
                      final data = t.data() as Map<String, dynamic>?;
                      return data?['status'] == 'healthy';
                    }).length;

                    int attention = trees.where((t) {
                      final data = t.data() as Map<String, dynamic>?;
                      return data?['status'] == 'attention';
                    }).length;

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: "My Trees",
                            value: total.toString(),
                            icon: Icons.park,
                            onTap: () => context.push('/my-trees'),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: _StatCard(
                            title: "Healthy",
                            value: healthy.toString(),
                            icon: Icons.favorite,
                            onTap: () => context.push('/my-trees?filter=healthy'),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: _StatCard(
                            title: "Need Attention",
                            value: attention.toString(),
                            icon: Icons.warning, 
                            warning: true,
                            onTap: () => context.push('/my-trees?filter=attention'),
                          ),
                        ),
                      ],
                    );
                  },
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

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final tasks = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];

                      return _TaskCard(
                        title: task['title'],
                        subtitle: task['subtitle'],
                        button: task['type'] == 'scan' ? "SCAN NOW" : "VIEW DETAILS",
                        warning: task['type'] != 'scan',
                      );
                    },
                  );
                },
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

/// STAT CARD
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFEED9B7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, textAlign: TextAlign.center),

            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: warning ? Colors.orange : Colors.green,
              ),
            ),

            Icon(
              icon,
              size: 40,   // 🔥 BIG ICON LIKE DESIGN
              color: warning ? Colors.orange : Colors.green,
            ),
          ],
        )
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
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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

/// 🔥 SYNC DETAILS SHEET
class SyncDetailsSheet extends StatefulWidget {
  final String status;
  final String lastSync;

  const SyncDetailsSheet({
    super.key,
    required this.status,
    required this.lastSync,
  });

  @override
  State<SyncDetailsSheet> createState() => _SyncDetailsSheetState();
}

class _SyncDetailsSheetState extends State<SyncDetailsSheet> {
  bool isOnline = false;
  int pendingUploads = 3;
  int localChanges = 5;
  bool isSyncing = false;
  String lastResult = "Success";

  final syncService = SyncService();

  @override
  void initState() {
    super.initState();
    checkConnection();
  }

  Future<void> checkConnection() async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result.any((item) => item != ConnectivityResult.none);
    });
  }

  Future<void> syncNow() async {
    setState(() => isSyncing = true);

    try {
      await syncService.updateLastSync();
      setState(() {
        lastResult = "Success";
        pendingUploads = 0;
        localChanges = 0;
      });
    } catch (e) {
      setState(() {
        lastResult = "Failed";
      });
    }

    setState(() => isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sync Details",
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _row("Status", isOnline ? "Online" : "Offline",
              color: isOnline ? Colors.green : Colors.red),

          _row("Last Sync", widget.lastSync),

          _row("Pending Uploads", "$pendingUploads items"),

          _row("Local Changes", "$localChanges unsynced"),

          _row("Last Result", lastResult,
              color: lastResult == "Success"
                  ? Colors.green
                  : Colors.red),

          const SizedBox(height: 10),

          if (isSyncing)
            const Center(child: CircularProgressIndicator()),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSyncing ? null : syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text("Sync Now"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
/// 🔔 NOTIFICATION SHEET
class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          Expanded(
            child: ListView(
              children: const [
                _NotificationSection(
                  title: "🌧 Weather Alerts",
                  items: [
                    NotificationItem("Rain expected today", "2 mins ago"),
                    NotificationItem("High temperature warning", "1 hour ago"),
                  ],
                ),
                _NotificationSection(
                  title: "⏰ Reminders",
                  items: [
                    NotificationItem("Task reminder", "10 mins ago"),
                    NotificationItem("Report reminder", "30 mins ago"),
                  ],
                ),
                _NotificationSection(
                  title: "⚠️ Alerts",
                  items: [
                    NotificationItem("Tree requires attention", "5 mins ago"),
                  ],
                ),
                _NotificationSection(
                  title: "🔄 System Updates",
                  items: [
                    NotificationItem("Sync completed", "1 hour ago"),
                    NotificationItem("Report generated", "2 hours ago"),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class IssueTrackerScreen extends StatelessWidget {
  const IssueTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: Column(
          children: [

            /// HEADER
            Container(
              width: double.infinity,
              color: Colors.green[800],
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Namaste,",
                          style: TextStyle(color: Colors.white70)),
                      Text("Manager",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),

            /// BODY
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [

                    /// 🔥 TOP CARDS (REAL DATA)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [

                          /// TOTAL ISSUES
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('issues')
                                  .snapshots(),
                              builder: (context, snapshot) {

                                int total = 0;
                                if (snapshot.hasData) {
                                  total = snapshot.data!.docs.length;
                                }

                                return GestureDetector(
                                  onTap: () =>
                                      context.push('/total-issues'),
                                  child: topCard(
                                      "Total Issues",
                                      "$total",
                                      "All Farms"),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          /// CRITICAL ISSUES
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('issues')
                                  .where('status', isEqualTo: 'critical')
                                  .snapshots(),
                              builder: (context, snapshot) {

                                int critical = 0;
                                if (snapshot.hasData) {
                                  critical = snapshot.data!.docs.length;
                                }

                                return topCard(
                                    "Critical",
                                    "$critical",
                                    "Needs Attention");
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ISSUE SUMMARY
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('issues')
                          .snapshots(),
                      builder: (context, snapshot) {

                        int total = 0;
                        int critical = 0;
                        int progress = 0;
                        int resolved = 0;

                        if (snapshot.hasData) {
                          final docs = snapshot.data!.docs;
                          total = docs.length;

                          for (var doc in docs) {
                            final data =
                                doc.data() as Map<String, dynamic>;
                            String status =
                                (data['status'] ?? '').toLowerCase();

                            if (status == 'critical') critical++;
                            if (status == 'in progress') progress++;
                            if (status == 'resolved') resolved++;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              const Text("Issue Summary",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),

                              const SizedBox(height: 10),

                              buildProgress("Critical", Colors.red,
                                  total == 0 ? 0 : critical / total,
                                  "$critical"),

                              buildProgress("In Progress", Colors.orange,
                                  total == 0 ? 0 : progress / total,
                                  "$progress"),

                              buildProgress("Resolved", Colors.green,
                                  total == 0 ? 0 : resolved / total,
                                  "$resolved"),
                            ],
                          ),
                        );
                      },
                    ),

                    /// ACTIVE ISSUES FEED
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Active Issues Feed",
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('issues')
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("No issues available"),
                          );
                        }

                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;

                            return issueCard(
                              _getBgColor(data['status']),
                              _getIcon(data['status']),
                              _getIconColor(data['status']),
                              data['title'] ?? "Issue",
                              data['farm'] ?? "Unknown Farm",
                              data['status'] ?? "Open",
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      /// 🔻 NAV BAR (OPTIONAL)
      bottomNavigationBar: _navBar(context),
    );
  }

  /// ================= HELPERS =================

  Widget topCard(String title, String count, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          Text(count,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget buildProgress(
      String title, Color color, double value, String count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: value,
              color: color,
              backgroundColor: color.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 6),
          Text(count),
        ],
      ),
    );
  }

  Widget issueCard(Color bg, IconData icon, Color iconColor,
      String title, String sub, String tag) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: Text("$title\n$sub")),
          Text(tag)
        ],
      ),
    );
  }

  Color _getBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical':
        return Colors.red.shade200;
      case 'resolved':
        return Colors.green.shade200;
      default:
        return Colors.orange.shade200;
    }
  }

  IconData _getIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.timelapse;
    }
  }

  Color _getIconColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _navBar(BuildContext context) {
    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [

          GestureDetector(
            onTap: () => context.go('/home'),
            child: const Icon(Icons.home),
          ),

          GestureDetector(
            onTap: () => context.go('/farms'),
            child: const Icon(Icons.park),
          ),

          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green,
            child: Icon(Icons.qr_code, color: Colors.white),
          ),

          GestureDetector(
            onTap: () => context.go('/analytics'),
            child: const Icon(Icons.bar_chart),
          ),

          GestureDetector(
            onTap: () => context.go('/profile'),
            child: const Icon(Icons.person),
          ),
        ],
      ),
    );
  }
}
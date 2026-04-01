import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TreeDetailsPage extends StatelessWidget {
  final String docId;

  const TreeDetailsPage({
    super.key,
    required this.docId,
  });

  // ✅ SAFE VALUE
  String getValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) {
      return "No Data";
    }
    return value.toString();
  }

  // ✅ SAFE DATE
  String getDate(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is Timestamp) {
      return value.toDate().toString();
    }

    return "No Date";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tree Details"),
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trees')
            .doc(docId)
            .snapshots(),

        builder: (context, snapshot) {
          // 🔴 ERROR
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // ⏳ LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ NO DOCUMENT
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Tree not found"));
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          // 🔍 DEBUG (OPTIONAL)
          print("TREE DATA: $data");

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              child: Padding(
                padding: const EdgeInsets.all(16),

                child: ListView(
                  children: [
                    _row("🌳 Tree ID", getValue(data, 'treeId')),
                    _row("📍 Location", getValue(data, 'location')),
                    _row("📅 Age", getValue(data, 'age')),
                    _row("💚 Health", getValue(data, 'healthStatus')),
                    _row("📡 RFID", getValue(data, 'rfid')),
                    _row("🌾 Yield", getValue(data, 'lastyield')),
                    _row("🔄 Sync", getValue(data, 'syncStatus')),
                    _row("👤 User ID", getValue(data, 'userId')),

                    const Divider(),

                    _row("🕒 Created", getDate(data, 'createAt')),
                    _row("🔍 Inspection", getDate(data, 'lastinspectiondate')),
                    _row("☁️ Synced At", getDate(data, 'lastSyncedAt')),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        "$title: $value",
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
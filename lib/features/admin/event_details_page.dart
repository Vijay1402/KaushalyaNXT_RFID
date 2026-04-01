import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventDetailsPage extends StatelessWidget {
  final String eventId;

  const EventDetailsPage({
    super.key,
    required this.eventId,
  });

  String getValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null || value.toString().isEmpty) {
      return "No Data";
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Event Details")),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tree_events')
            .doc(eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Event not found"));
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("📅 Type: ${getValue(data, 'eventType')}"),
              Text("🌳 Tree: ${getValue(data, 'treeId')}"),
              Text("📝 Notes: ${getValue(data, 'notes')}"),
              Text("📍 Location: ${getValue(data, 'location')}"),
              Text("👤 Performed By: ${getValue(data, 'performedBy')}"),
              Text("🔄 Sync: ${getValue(data, 'syncStatus')}"),
            ],
          );
        },
      ),
    );
  }
}
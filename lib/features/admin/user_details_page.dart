import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailsPage extends StatelessWidget {
  final String userId;

  const UserDetailsPage({
    super.key,
    required this.userId,
  });

  // ✅ SAFE VALUE FUNCTION
  String getValue(Map<String, dynamic>? data, String key) {
    if (data == null) return "No Data";

    final value = data[key];

    if (value == null || value.toString().trim().isEmpty) {
      return "No Data";
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Details"),
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
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
            return const Center(child: Text("User not found"));
          }

          // ✅ SAFE CAST
          final data =
              snapshot.data!.data() as Map<String, dynamic>?;

          // 🔥 DEBUG (VERY IMPORTANT)
          print("USER DATA FULL: ${snapshot.data!.data()}");
          print("ROLE VALUE: ${data?['role']}");

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
                    _row("👤 Name", getValue(data, 'name')),
                    _row("📧 Email", getValue(data, 'email')),
                    _row("🆔 User ID", userId),

                    // 🔥 ROLE (MAIN FIX AREA)
                    _row("🎭 Role", getValue(data, 'role')),

                    const Divider(),

                    // OPTIONAL FIELDS
                    _row("📞 Phone", getValue(data, 'phone')),
                    _row("📍 Location", getValue(data, 'location')),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ UI ROW
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
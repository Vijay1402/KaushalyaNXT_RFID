import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AddTreePage extends StatefulWidget {
  const AddTreePage({super.key});

  @override
  State<AddTreePage> createState() => _AddTreePageState();
}

class _AddTreePageState extends State<AddTreePage> {
  final TextEditingController treeIdController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  String healthStatus = "healthy"; // ✅ default

  // ✅ ADD TREE FUNCTION
  Future<void> addTree() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    if (treeIdController.text.isEmpty || ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    int age;
    try {
      age = int.parse(ageController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Age must be a number")),
      );
      return;
    }

    final treeId = const Uuid().v4();

    // ✅ SAVE TO FIRESTORE
    await FirebaseFirestore.instance
        .collection('trees')
        .doc(treeId)
        .set({
      "treeId": treeId,
      "farmerId": user.uid,
      "age": age,
      "healthStatus": healthStatus,

      "lastInspectionDate": Timestamp.now(),
      "lastYield": 0,

      "latitude": 0.0,
      "longitude": 0.0,

      "rfidTagId": "RF${DateTime.now().millisecondsSinceEpoch}",

      "lastSyncedAt": Timestamp.now(),
      "syncStatus": "synced",

      "createdAt": Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Tree added successfully")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Tree")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // TREE ID (optional display)
            TextField(
              controller: treeIdController,
              decoration: const InputDecoration(
                labelText: "Tree Name / ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // AGE
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Age",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // ✅ HEALTH DROPDOWN
            DropdownButtonFormField<String>(
              value: healthStatus,
              decoration: const InputDecoration(
                labelText: "Health Status",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: "healthy", child: Text("Healthy")),
                DropdownMenuItem(
                    value: "needs_attention",
                    child: Text("Needs Attention")),
                DropdownMenuItem(
                    value: "critical", child: Text("Critical")),
              ],
              onChanged: (value) {
                setState(() {
                  healthStatus = value!;
                });
              },
            ),
            const SizedBox(height: 20),

            // ADD BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: addTree,
                child: const Text("Add Tree"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
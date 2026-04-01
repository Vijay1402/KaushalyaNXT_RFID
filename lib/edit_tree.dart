import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTreePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditTreePage({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditTreePage> createState() => _EditTreePageState();
}

class _EditTreePageState extends State<EditTreePage> {
  late TextEditingController treeIdController;
  late TextEditingController locationController;
  late TextEditingController ageController;

  String healthStatus = "healthy";

  @override
  void initState() {
    super.initState();

    treeIdController =
        TextEditingController(text: widget.data['treeId'] ?? '');

    locationController =
        TextEditingController(text: widget.data['location'] ?? '');

    ageController = TextEditingController(
        text: widget.data['age']?.toString() ?? '');

    healthStatus = widget.data['healthStatus'] ?? "healthy";
  }

  Future<void> updateTree() async {
    try {
      if (treeIdController.text.isEmpty ||
          locationController.text.isEmpty ||
          ageController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")),
        );
        return;
      }

      final age = int.tryParse(ageController.text);
      if (age == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Age must be a number")),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('trees')
          .doc(widget.docId)
          .update({
        'treeId': treeIdController.text.trim(),
        'location': locationController.text.trim(),
        'age': age,
        'healthStatus': healthStatus,

        // 🔥 update sync info
        'lastSyncedAt': Timestamp.now(),
        'syncStatus': 'updated',
      });

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tree updated successfully")),
        );
      }
    } catch (e) {
      print("ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Tree")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // TREE ID
              TextField(
                controller: treeIdController,
                decoration: const InputDecoration(
                  labelText: "Tree ID",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // LOCATION
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: "Location",
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

              // UPDATE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: updateTree,
                  child: const Text("Update"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
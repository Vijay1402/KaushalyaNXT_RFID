import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class TreesPage extends StatefulWidget {
  const TreesPage({super.key});

  @override
  State<TreesPage> createState() => _TreesPageState();
}

class _TreesPageState extends State<TreesPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // ✅ ADD TREE
  Future<void> addTree() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ User not logged in");
      return;
    }

    print("✅ Adding tree for UID: ${user.uid}");

    await FirebaseFirestore.instance.collection('trees').add({
      'name': nameController.text.trim(),
      'location': locationController.text.trim(),
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    nameController.clear();
    locationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    print("🔥 Current UID: ${user?.uid}");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trees"),
        centerTitle: true,
      ),
      body: Column(
        children: [

          // 🔹 INPUT SECTION
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Tree Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: "Location",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

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

          const Divider(),

          // 🔥 LIST SECTION
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trees')
                  .snapshots(),
              builder: (context, snapshot) {

                print("📡 STREAM TRIGGERED");
                print("📊 Docs count: ${snapshot.data?.docs.length}");

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}"),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No Trees Found"));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;

                    String name = data['name'] ?? "No Name";
                    String location =
                        data['location'] ?? "No Location";

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),

                          // ✅ TAP WORKING
                          onTap: () {
                            print("CLICKED");

                            context.push(
                              '/tree-details',
                              extra: {
                                'name': name,
                                'location': location,
                              },
                            );
                          },

                          child: ListTile(
                            leading: const Icon(Icons.park),
                            title: Text(name),
                            subtitle: Text(location),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 🌳 DETAILS PAGE
class TreeDetailsPage extends StatelessWidget {
  final String name;
  final String location;

  const TreeDetailsPage({
    super.key,
    required this.name,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tree Details")),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: ListTile(
            leading: const Icon(Icons.park, size: 40),
            title: Text(
              name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(location),
          ),
        ),
      ),
    );
  }
}
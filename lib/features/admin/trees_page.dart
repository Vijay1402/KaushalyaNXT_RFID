import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class TreesPage extends StatelessWidget {
  const TreesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Farm Data"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Trees"),
              Tab(text: "Events"),
              Tab(text: "Users"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TreesTab(),
            TreeEventsTab(),
            UsersTab(),
          ],
        ),
      ),
    );
  }
}

//
// 🌳 TREES TAB
//
class TreesTab extends StatelessWidget {
  const TreesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final trees = FirebaseFirestore.instance.collection('trees');

    return StreamBuilder<QuerySnapshot>(
      stream: trees.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.park),
                title: Text(data['treeId'] ?? ''),
                subtitle: Text(data['location'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  context.pushNamed(
                    'treeDetails',
                    extra: doc.id,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

//
// 📅 EVENTS TAB (🔥 FIXED CLICK)
//
class TreeEventsTab extends StatelessWidget {
  const TreeEventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final events =
        FirebaseFirestore.instance.collection('tree_events');

    return StreamBuilder<QuerySnapshot>(
      stream: events.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data =
                doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text(data['eventType'] ?? ''),
                subtitle: Text(data['treeId'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios),

                // 🔥 CLICK FIX
                onTap: () {
                  context.pushNamed(
                    'eventDetails',
                    extra: doc.id,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

//
// 👤 USERS TAB
//
class UsersTab extends StatelessWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');

    return StreamBuilder<QuerySnapshot>(
      stream: users.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data =
                doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? ''),
                subtitle: Text(data['email'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  context.pushNamed(
                    'userDetails',
                    extra: doc.id,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
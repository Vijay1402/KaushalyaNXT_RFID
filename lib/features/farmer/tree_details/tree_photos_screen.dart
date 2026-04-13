// ============================================================
//  lib/features/farmer/tree_details/tree_photos_screen.dart
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';

class TreePhotosScreen extends StatelessWidget {
  final Tree tree;
  final String treeDocId;

  const TreePhotosScreen({
    super.key,
    required this.tree,
    required this.treeDocId,
  });

  static const _green1 = Color(0xFF1E4D2B);

  // Mock photo entries — replace with real URLs from your backend later
  static const List<Map<String, String>> _mockPhotos = [
    {
      'label': 'Full Tree View',
      'date': 'Dec 10, 2024',
      'by': 'Field Officer A. Singh'
    },
    {
      'label': 'Trunk Close-up',
      'date': 'Nov 20, 2024',
      'by': 'Field Officer R. Mehta'
    },
    {
      'label': 'Leaf Sample',
      'date': 'Oct 5, 2024',
      'by': 'Field Officer A. Singh'
    },
    {
      'label': 'Root Area',
      'date': 'Sep 14, 2024',
      'by': 'Field Officer R. Mehta'
    },
    {
      'label': 'Fruit Inspection',
      'date': 'Aug 22, 2024',
      'by': 'Field Officer A. Singh'
    },
    {
      'label': 'Disease Spot (Bark)',
      'date': 'Jul 30, 2024',
      'by': 'Field Officer R. Mehta'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('${tree.name} — Photos'),
        backgroundColor: _green1,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera upload coming soon')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('trees')
            .doc(treeDocId)
            .collection('issues')
            .where('hasImage', isEqualTo: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load photos from Firebase.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    (doc.data()['imageUrl'] ?? '').toString().trim().isNotEmpty,
              )
              .toList(growable: false);

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No Firebase photos available for this tree.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(14),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final imageUrl = (data['imageUrl'] ?? '').toString();
                final note = (data['note'] ?? '').toString().trim();
                final reporter =
                    (data['reportedByEmail'] ?? data['ownerName'] ?? '')
                        .toString()
                        .trim();
                final createdAt = data['createdAt'];
                final dateText = createdAt is Timestamp
                    ? _formatDate(createdAt.toDate())
                    : 'Uploaded image';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 36,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.isEmpty ? 'Issue photo' : note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateText,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              reporter.isEmpty ? 'Firebase' : reporter,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

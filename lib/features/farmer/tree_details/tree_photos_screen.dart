// ============================================================
//  lib/features/farmer/tree_details/tree_photos_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';

class TreePhotosScreen extends StatelessWidget {
  final Tree tree;
  const TreePhotosScreen({super.key, required this.tree});

  static const _green1 = Color(0xFF1E4D2B);

  // Mock photo entries — replace with real URLs from your backend later
  static const List<Map<String, String>> _mockPhotos = [
    {'label': 'Full Tree View',      'date': 'Dec 10, 2024', 'by': 'Field Officer A. Singh'},
    {'label': 'Trunk Close-up',      'date': 'Nov 20, 2024', 'by': 'Field Officer R. Mehta'},
    {'label': 'Leaf Sample',         'date': 'Oct 5, 2024',  'by': 'Field Officer A. Singh'},
    {'label': 'Root Area',           'date': 'Sep 14, 2024', 'by': 'Field Officer R. Mehta'},
    {'label': 'Fruit Inspection',    'date': 'Aug 22, 2024', 'by': 'Field Officer A. Singh'},
    {'label': 'Disease Spot (Bark)', 'date': 'Jul 30, 2024', 'by': 'Field Officer R. Mehta'},
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
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: _mockPhotos.length,
          itemBuilder: (context, index) {
            final photo = _mockPhotos[index];
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
                  // Photo placeholder
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade300,
                            Colors.green.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                      ),
                      child: Center(
                        child: Icon(Icons.park,
                            size: 50,
                            color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  // Label
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(photo['label']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(photo['date']!,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 10)),
                        Text(photo['by']!,
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 9),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
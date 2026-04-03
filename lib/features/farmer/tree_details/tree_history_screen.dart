// ============================================================
//  lib/features/farmer/tree_details/tree_history_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/tree_model.dart';

class TreeHistoryScreen extends StatelessWidget {
  final Tree tree;
  const TreeHistoryScreen({super.key, required this.tree});

  static const _green1 = Color(0xFF1E4D2B);
  static const _green2 = Color(0xFF2D6A3F);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');

    // Combine health history + maintenance records into one timeline
    final List<Map<String, dynamic>> events = [
      ...tree.healthHistory.map((h) => {
        'date': h.date,
        'type': 'health',
        'title': 'Health Check',
        'subtitle': h.note,
        'by': h.recordedBy,
        'status': h.status,
      }),
      ...tree.maintenanceRecords.map((m) => {
        'date': m.date,
        'type': 'maintenance',
        'title': m.type,
        'subtitle': 'Maintenance performed',
        'by': m.technician,
        'status': null,
      }),
    ]..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('${tree.name} — History'),
        backgroundColor: _green1,
        foregroundColor: Colors.white,
      ),
      body: events.isEmpty
          ? const Center(child: Text('No history records available.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                final isHealth = e['type'] == 'health';
                final color = isHealth ? Colors.purple : Colors.blue;
                final icon  = isHealth ? Icons.favorite : Icons.build_circle_outlined;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line + dot
                    Column(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        if (index < events.length - 1)
                          Container(
                            width: 2, height: 40,
                            color: Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e['title'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(fmt.format(e['date'] as DateTime),
                                    style: TextStyle(
                                        color: Colors.grey.shade500, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(e['subtitle'] as String,
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.person_outline,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('By: ${e['by']}',
                                  style: TextStyle(
                                      color: Colors.grey.shade500, fontSize: 11)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
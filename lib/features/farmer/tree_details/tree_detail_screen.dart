import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'tree_controller.dart';
import '../../rfid/rfid_scan_screen.dart';

class TreeDetailScreen extends ConsumerWidget {
  final String treeId;

  const TreeDetailScreen({
    super.key,
    required this.treeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(treeByIdProvider(treeId));

    return treeAsync.when(
      data: (doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final treeIdText = data['treeId']?.toString() ?? 'No ID';
        final location = data['location']?.toString() ?? '';
        final rfid = data['rfid']?.toString() ?? 'No RFID';

        final age = (data['age'] is int)
            ? data['age']
            : int.tryParse(data['age']?.toString() ?? '0') ?? 0;

        final health = _statusLabel(data['healthStatus']);
        final lastInspection = _parseDate(data['lastinspectiondate']);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),

          body: CustomScrollView(
            slivers: [

              /// ✅ FIXED HEADER (NO OVERFLOW)
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,

                title: const Text(
                  "Tree Details",
                  style: TextStyle(color: Colors.white),
                ),

                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF4CAF50),
                      ],
                    ),
                  ),

                  child: SafeArea(
                    child: Stack(
                      children: [

                        /// 🌕 AGE
                        Positioned(
                          left: 16,
                          top: 60,
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.shade400,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text("$age",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold)),
                                  const Text("YRS",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8)),
                                ],
                              ),
                            ),
                          ),
                        ),

                        /// 🌳 TREE NAME
                        Positioned(
                          left: 16,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                treeIdText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const Text(
                                "Mangifera indica",
                                style: TextStyle(
                                    color: Colors.white70),
                              ),
                            ],
                          ),
                        ),

                        /// ✅ HEALTH
                        Positioned(
                          right: 16,
                          top: 70,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF66BB6A),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check,
                                    size: 12,
                                    color: Colors.white),
                                const SizedBox(width: 4),
                                Text(health,
                                    style: const TextStyle(
                                        color:
                                            Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// BODY
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 4, 14, 120),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      /// TOP CARDS
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              color: const Color(0xFFF1F8E9),
                              children: [
                                Text("Tree ID: $treeIdText"),
                                Text("Health: $health"),
                                Text("Age: $age yrs"),
                                const Text("Farmer: Rajesh Kumar"),
                                const Text("Yield: 120 kg/yr"),
                                Text("Last Scan: ${DateFormat('MMM d, yyyy').format(lastInspection)}"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _infoCard(
                              color: const Color(0xFFE3F2FD),
                              children: [
                                _menuItem(Icons.history,
                                    "Full History"),
                                _menuItem(Icons.photo,
                                    "Photos"),
                                _menuItem(Icons.wb_sunny,
                                    "Weather"),
                                _menuItem(Icons.show_chart,
                                    "Predictions"),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// RFID
                      _infoCard(
                        color: const Color(0xFFFFF8E1),
                        border:
                            Border.all(color: Colors.orange),
                        children: [
                          const Text(
                              "RFID Tag Status Panel"),
                          const SizedBox(height: 10),
                          Text("Tag ID: $rfid"),
                          const Text("Status: Active"),
                          const Text("Battery: 85%"),
                        ],
                      ),

                      _card("Tree Profile", [
                        _row("Location", location),
                        _row("Species",
                            "Mangifera indica"),
                      ]),

                      _card("Inspection & Care", [
                        _row(
                            "Last Inspection",
                            DateFormat('MMM d, yyyy')
                                .format(
                                    lastInspection)),
                        const Text(
                            "Notes: Main tree in the northern sector."),
                      ]),

                      _card("Growth Statistics", [
                        _row("Age", "$age yrs"),
                        _row("Health", health),
                      ]),

                      _card("Location", [
                        _row("Plot", location),
                        _row("Lat", "12.9716"),
                        _row("Lng", "77.5946"),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// BUTTONS
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("Schedule"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const RFIDScanScreen(),
                        ),
                      );
                    },
                    child: const Text("Scan Tag"),
                  ),
                ),
              ],
            ),
          ),
        );
      },

      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),

      error: (e, _) =>
          Scaffold(body: Center(child: Text("Error: $e"))),
    );
  }

  /// COMPONENTS

  Widget _menuItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 12),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoCard(
      {required List<Widget> children,
      Color? color,
      Border? border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Text("$label: $value");
  }

  String _statusLabel(String? status) {
    switch (status) {
      case "0":
        return "Healthy";
      case "1":
        return "Needs Attention";
      case "2":
        return "At Risk";
      case "3":
        return "Sick";
      default:
        return "Healthy";
    }
  }

  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) return date.toDate();
    return DateTime.tryParse(date.toString()) ??
        DateTime.now();
  }
}
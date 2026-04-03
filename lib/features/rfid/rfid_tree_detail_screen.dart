// ============================================================
//  lib/features/rfid/rfid_tree_detail_screen.dart
// ============================================================
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models/tree_model.dart';
import 'rfid_scan_screen.dart';

class TreeDetailScreen extends StatefulWidget {
  final Tree tree;
  final String dataSource;

  const TreeDetailScreen({
    super.key,
    required this.tree,
    this.dataSource = 'local',
  });

  @override
  State<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends State<TreeDetailScreen> {
  // ── Colours ───────────────────────────────────────────────────────────────
  static const _dark    = Color(0xFF1A2E1C);
  static const _green1  = Color(0xFF1E4D2B);
  static const _green2  = Color(0xFF2D6A3F);
  static const _tagBg   = Color(0xFFF5F9EC);
  static const _cloudBg = Color(0xFFEBF4FF);

  // ── Connectivity state ────────────────────────────────────────────────────
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Listen for changes while screen is open
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() => _isOnline = result != ConnectivityResult.none);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = result != ConnectivityResult.none);
    }
  }

  // ── Report Issue bottom sheet ─────────────────────────────────────────────
  void _showReportIssue() {
    final noteController = TextEditingController();
    File? pickedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickImage(ImageSource source) async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: source,
                imageQuality: 70,
                maxWidth: 1080,
              );
              if (picked != null) {
                setSheet(() => pickedImage = File(picked.path));
              }
            }

            return Padding(
              // Pushes sheet up when keyboard opens
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Handle ────────────────────────────────────
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Title ─────────────────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.report_problem_outlined,
                            color: Colors.red.shade600, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('Report an Issue',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Tree: ${widget.tree.name} · ${widget.tree.id}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),

                    const SizedBox(height: 20),

                    // ── Image section ─────────────────────────────
                    const Text('Photo of Issue',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('Take a photo or pick from gallery',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(height: 12),

                    // Image preview or pick buttons
                    if (pickedImage != null) ...[
                      // Show picked image with remove option
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              pickedImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setSheet(() => pickedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Change photo button
                      OutlinedButton.icon(
                        onPressed: () => pickImage(ImageSource.camera),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Change Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green2,
                          side: const BorderSide(color: _green2),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ] else ...[
                      // Two big buttons — Camera & Gallery
                      Row(children: [
                        Expanded(
                          child: _imagePickButton(
                            icon: Icons.camera_alt,
                            label: 'Camera',
                            color: _green1,
                            onTap: () => pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _imagePickButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Gallery',
                            color: Colors.blue.shade700,
                            onTap: () => pickImage(ImageSource.gallery),
                          ),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 20),

                    // ── Note field (optional) ──────────────────────
                    Row(children: [
                      const Text('Note',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('(optional)',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ]),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Describe the issue...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _green2, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Submit button ──────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Issue reported successfully!'),
                              ]),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Submit Report',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _imagePickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildTagCloudPanel(context),
                  const SizedBox(height: 12),
                  _buildRFIDStatusPanel(),
                  const SizedBox(height: 12),
                  _buildTreeProfileCard(),
                  const SizedBox(height: 12),
                  _buildInspectionCard(),
                  const SizedBox(height: 12),
                  _buildGrowthStatsCard(),
                  const SizedBox(height: 12),
                  _buildGPSCard(),
                  const SizedBox(height: 12),
                  _buildNotesCard(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _green1,
      foregroundColor: Colors.white,

      // ── Online/offline dot next to title ──────────────────────
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tree Details',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _isOnline
                  ? Colors.green.shade400.withValues(alpha: 0.25)
                  : Colors.red.shade400.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isOnline
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : Colors.redAccent.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'online' : 'offline',
                  style: TextStyle(
                    color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade900, Colors.green.shade600, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.park, size: 100, color: Colors.white12),
            ),
            // Bottom fade
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Age badge (top left) ──────────────────────────
            Positioned(
              top: 80, left: 16,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.amber.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.park, color: Colors.white, size: 12),
                    Text('${widget.tree.ageInYears}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const Text('YRS OLD',
                        style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),

            // ── Health badge (top right) ──────────────────────
            Positioned(
              top: 90, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.tree.currentStatus),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: _getStatusColor(widget.tree.currentStatus).withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(_statusLabel(widget.tree.currentStatus),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            ),

            // ── Report Issue button (circled area) ────────────
            // Shows only when online, sits below health badge on right
            if (_isOnline)
              Positioned(
                top: 134, right: 16,
                child: GestureDetector(
                  onTap: _showReportIssue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.report_problem_outlined,
                            color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Report Issue',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Tree name (bottom left) ───────────────────────
            Positioned(
              bottom: 14, left: 16, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.tree.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
                  Text(widget.tree.species,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── From Tag | From Cloud Panel ───────────────────────────────────────────
  Widget _buildTagCloudPanel(BuildContext context) {
    final lastInspection = widget.tree.healthHistory.isNotEmpty
        ? widget.tree.healthHistory.last.date : widget.tree.lastInspectionDate;
    final daysSince = DateTime.now().difference(lastInspection).inDays;
    final lastScanStr = daysSince == 0 ? 'Today' : daysSince == 1 ? 'Yesterday' : '$daysSince days ago';
    final yieldKg = widget.tree.maintenanceRecords.length * 48 + 50;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // FROM TAG
            Expanded(
              child: Container(
                color: _tagBg,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.sensors, color: _green2, size: 16),
                      SizedBox(width: 6),
                      Text('From Tag', style: TextStyle(color: _green2, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    _tagRow('🌳', 'Tree ID', widget.tree.id),
                    _tagRow('👤', 'Farmer', 'R. Kumar'),
                    _tagRow('💚', 'Health', _statusLabel(widget.tree.currentStatus)),
                    _tagRow('🏆', 'Yield', '$yieldKg kg/yr'),
                    _tagRow('📅', 'Age', '${widget.tree.ageInYears} yrs'),
                    _tagRow('🔍', 'Last Scan', lastScanStr),
                  ],
                ),
              ),
            ),

            // FROM CLOUD
            Expanded(
              child: Container(
                color: _cloudBg,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.cloud, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 6),
                      Text('From Cloud',
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cloudRow(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, size: 10, color: color),
        ]),
      ),
    );
  }

  // ── RFID Status Panel ─────────────────────────────────────────────────────
  Widget _buildRFIDStatusPanel() {
    final now = DateTime.now();
    final h   = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m   = now.minute.toString().padLeft(2, '0');
    final ampm= now.hour >= 12 ? 'PM' : 'AM';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.nfc_rounded, color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 6),
            Text('RFID Tag Status Panel',
                style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Text('Tag ID: ${widget.tree.rfidTag}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dark, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 6),
            Text('Status: ', style: TextStyle(fontSize: 13)),
            Text('Active (In Range)',
                style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          _rfidRow('Last Scan Time', 'Today, $h:$m $ampm'),
          _rfidRow('Battery Level', '85% (Good)'),
          _rfidRow('Plot Number', widget.tree.plotNumber),
        ],
      ),
    );
  }

  Widget _rfidRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // ── Tree Profile Card ─────────────────────────────────────────────────────
  Widget _buildTreeProfileCard() {
    final fmt = DateFormat('MMM d, yyyy');
    return _infoCard(
      title: 'Tree Profile', icon: Icons.park, iconColor: _green2,
      children: [
        _profileRow('Farmer', 'Rajesh Kumar'),
        _profileRow('Location', 'Plot ${widget.tree.plotNumber}, Karnataka, India'),
        _profileRow('Coordinates',
            '${widget.tree.latitude.toStringAsFixed(4)}° N, ${widget.tree.longitude.toStringAsFixed(4)}° E'),
        _profileRow('Species', widget.tree.species),
        _profileRow('Planted On', fmt.format(widget.tree.plantingDate)),
        _profileRow('Expected Next Yield', '${widget.tree.maintenanceRecords.length * 48 + 100} kg'),
      ],
    );
  }

  // ── Inspection & Care Card ────────────────────────────────────────────────
  Widget _buildInspectionCard() {
    final fmt = DateFormat('MMM d, yyyy');
    final lastRecord  = widget.tree.healthHistory.isNotEmpty ? widget.tree.healthHistory.last : null;
    final lastMainten = widget.tree.maintenanceRecords.isNotEmpty ? widget.tree.maintenanceRecords.last : null;

    return _infoCard(
      title: 'Inspection & Care', icon: Icons.medical_services_outlined, iconColor: Colors.teal,
      children: [
        _profileRow('Last Inspection',
            lastRecord != null
                ? '${fmt.format(lastRecord.date)} by ${lastRecord.recordedBy}'
                : fmt.format(widget.tree.lastInspectionDate)),
        if (lastRecord != null) _profileRow('Notes', lastRecord.note),
        if (lastMainten != null) ...[
          _profileRow('Last Maintenance', '${lastMainten.type} — ${fmt.format(lastMainten.date)}'),
          _profileRow('Technician', lastMainten.technician),
        ],
        _profileRow('Next Due', fmt.format(widget.tree.lastInspectionDate.add(const Duration(days: 30)))),
      ],
    );
  }

  // ── Growth Stats Card ─────────────────────────────────────────────────────
  Widget _buildGrowthStatsCard() {
    return _infoCard(
      title: 'Growth Statistics', icon: Icons.trending_up, iconColor: Colors.blue.shade700,
      children: [
        Row(children: [
          Expanded(child: _statBox('Age', '${widget.tree.ageInYears} yrs', Icons.calendar_today, _green2)),
          const SizedBox(width: 10),
          Expanded(child: _statBox('Health', _statusLabel(widget.tree.currentStatus),
              Icons.favorite, _getStatusColor(widget.tree.currentStatus))),
          const SizedBox(width: 10),
          Expanded(child: _statBox('Scans', '${widget.tree.maintenanceRecords.length}',
              Icons.qr_code_scanner, Colors.orange)),
        ]),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    );
  }

  // ── GPS Card ──────────────────────────────────────────────────────────────
  Widget _buildGPSCard() {
    return _infoCard(
      title: 'Location', icon: Icons.location_on, iconColor: Colors.red,
      children: [
        _profileRow('Latitude', '${widget.tree.latitude.toStringAsFixed(6)}° N'),
        _profileRow('Longitude', '${widget.tree.longitude.toStringAsFixed(6)}° E'),
        _profileRow('Plot', widget.tree.plotNumber),
        const SizedBox(height: 4),
        const Row(children: [
          Icon(Icons.map_outlined, color: _green2, size: 15),
          SizedBox(width: 6),
          Text('View on Map',
              style: TextStyle(color: _green2, fontSize: 13,
                  fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
        ]),
      ],
    );
  }

  // ── Notes Card ────────────────────────────────────────────────────────────
  Widget _buildNotesCard() {
    return _infoCard(
      title: 'Worker Notes', icon: Icons.notes, iconColor: Colors.grey.shade700,
      children: [
        Text(
          widget.tree.notes.isNotEmpty ? widget.tree.notes : 'No notes available for this tree.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.event_outlined, size: 18),
            label: const Text('Schedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green2,
              side: const BorderSide(color: _green2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RFIDScanScreen())),
            icon: const Icon(Icons.sensors, size: 18),
            label: const Text('Scan Tag'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Reusable helpers ──────────────────────────────────────────────────────
  Widget _infoCard({required String title, required IconData icon,
      required Color iconColor, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 7),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TreeHealthStatus status) {
    switch (status) {
      case TreeHealthStatus.healthy:        return Colors.green;
      case TreeHealthStatus.atRisk:         return Colors.orange;
      case TreeHealthStatus.sick:           return Colors.red;
      case TreeHealthStatus.needsAttention: return Colors.blue;
    }
  }

  String _statusLabel(TreeHealthStatus status) {
    switch (status) {
      case TreeHealthStatus.healthy:        return 'Healthy';
      case TreeHealthStatus.atRisk:         return 'At Risk';
      case TreeHealthStatus.sick:           return 'Sick';
      case TreeHealthStatus.needsAttention: return 'Needs Attention';
    }
  }
}
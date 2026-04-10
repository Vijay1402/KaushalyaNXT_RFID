// ============================================================
//  lib/features/reports/reports_screen.dart
// ============================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';

// ─────────────────────────────────────────────────────────────
//  REPORTS SCREEN
// ─────────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  // ── Filter state ───────────────────────────────────────────
  String? _selectedSpecies; // null = all species
  String?
      _selectedHealth; // null = all | 'Healthy' | 'Unhealthy' | 'Recovering'

  // ── Species options (replace with your real ones later) ────
  final List<String> _allSpecies = [
    'Mango',
    'Jackfruit',
    'Apple',
    'Orange',
    'Pine',
    'Banana',
    'Coconut',
    'Guava',
  ];

  // ── Animation controllers ──────────────────────────────────
  late AnimationController _pieCtrl;
  late AnimationController _ageBarCtrl;
  late AnimationController _weekBarCtrl;
  late Animation<double> _pieAnim;
  late Animation<double> _ageBarAnim;
  late Animation<double> _weekBarAnim;

  // ── Colours ────────────────────────────────────────────────
  static const _dark = Color(0xFF1A2E1C);
  static const _green1 = Color(0xFF1E4D2B);
  static const _green2 = Color(0xFF2D6A3F);
  static const _green3 = Color(0xFF4E9B64);
  static const _green4 = Color(0xFFA5D6A7);
  static const _green5 = Color(0xFFC8E6C9);
  static const _orange = Color(0xFFE07B2A);
  static const _bg = Color(0xFFF7F5F0);
  static const _sub = Color(0xFF8FAF96);

  // ── Filtered tree list (recomputed on every filter change) ─
  List<Tree> get _filtered {
    return mockTrees.where((t) {
      // species filter
      if (_selectedSpecies != null &&
          !t.species.toLowerCase().contains(_selectedSpecies!.toLowerCase())) {
        return false;
      }
      // health filter
      if (_selectedHealth != null) {
        switch (_selectedHealth) {
          case 'Healthy':
            if (t.currentStatus != TreeHealthStatus.healthy) return false;
            break;
          case 'Unhealthy':
            if (t.currentStatus != TreeHealthStatus.atRisk &&
                t.currentStatus != TreeHealthStatus.sick) return false;
            break;
          case 'Recovering':
            if (t.currentStatus != TreeHealthStatus.needsAttention)
              return false;
            break;
        }
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runAnimations();
  }

  void _initAnimations() {
    _pieCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _ageBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _weekBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));

    _pieAnim = CurvedAnimation(parent: _pieCtrl, curve: Curves.easeOutCubic);
    _ageBarAnim =
        CurvedAnimation(parent: _ageBarCtrl, curve: Curves.easeOutCubic);
    _weekBarAnim =
        CurvedAnimation(parent: _weekBarCtrl, curve: Curves.easeOutCubic);
  }

  void _runAnimations() {
    _pieCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _ageBarCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) _weekBarCtrl.forward(from: 0);
    });
  }

  // Called whenever a filter changes — resets & reruns animations
  void _applyFilter(
      {String? species,
      String? health,
      bool clearSpecies = false,
      bool clearHealth = false}) {
    setState(() {
      if (clearSpecies) {
        _selectedSpecies = null;
      } else if (species != null) {
        _selectedSpecies = (_selectedSpecies == species) ? null : species;
      }
      if (clearHealth) {
        _selectedHealth = null;
      } else if (health != null) {
        _selectedHealth = (_selectedHealth == health) ? null : health;
      }
    });
    _runAnimations();
  }

  @override
  void dispose() {
    _pieCtrl.dispose();
    _ageBarCtrl.dispose();
    _weekBarCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final trees = _filtered;

    // ── Computed stats from filtered list ──────────────────────
    final total = trees.length;
    final healthy =
        trees.where((t) => t.currentStatus == TreeHealthStatus.healthy).length;
    final unhealthy = trees
        .where((t) =>
            t.currentStatus == TreeHealthStatus.atRisk ||
            t.currentStatus == TreeHealthStatus.sick)
        .length;
    final recovering = trees
        .where((t) => t.currentStatus == TreeHealthStatus.needsAttention)
        .length;

    final now = DateTime.now();
    final age0to1 =
        trees.where((t) => now.difference(t.plantingDate).inDays < 365).length;
    final age1to5 = trees.where((t) {
      final d = now.difference(t.plantingDate).inDays;
      return d >= 365 && d < 365 * 5;
    }).length;
    final age5plus = trees
        .where((t) => now.difference(t.plantingDate).inDays >= 365 * 5)
        .length;

    final totalYield = trees.fold<double>(
        0, (s, t) => s + (t.maintenanceRecords.length * 48.0 + 50));
    final avgYield = total > 0 ? totalYield / total : 0.0;
    final sortedYield = [...trees]..sort((a, b) =>
        b.maintenanceRecords.length.compareTo(a.maintenanceRecords.length));
    final topTree = sortedYield.isNotEmpty ? sortedYield.first : null;
    final topYieldKg =
        topTree != null ? (topTree.maintenanceRecords.length * 48.0 + 50) : 0.0;

    final base = math.max(total, 1);
    final weekCounts = [
      (base * 0.40).round(),
      (base * 0.70).round(),
      (base * 0.30).round(),
      (base * 0.85).round(),
      (base * 1.00).round(),
      (base * 0.25).round(),
      (base * 0.15).round(),
    ];
    final todayScans = (base * 0.18).round().clamp(1, 999);
    final weekScans = weekCounts.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              child: Column(
                children: [
                  // ── Yield overview ────────────────────────────
                  _buildYieldOverview(
                    total: total,
                    totalYield: totalYield,
                    avgYield: avgYield,
                    topTree: topTree?.name ?? 'N/A',
                    topYieldKg: topYieldKg,
                  ),
                  const SizedBox(height: 12),

                  // ── Health dist + Age dist ────────────────────
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildHealthDistCard(
                            total: total,
                            healthy: healthy,
                            unhealthy: unhealthy,
                            recovering: recovering,
                            todayScans: todayScans,
                            weekScans: weekScans,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAgeDistCard(
                            age0to1: age0to1,
                            age1to5: age1to5,
                            age5plus: age5plus,
                            todayScans: todayScans,
                            weekScans: weekScans,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Weekly trend ──────────────────────────────
                  _buildWeeklyTrendCard(weekCounts: weekCounts),
                  const SizedBox(height: 12),

                  // ── RFID activity ─────────────────────────────
                  _buildRFIDActivityCard(
                    todayScans: todayScans,
                    weekScans: weekScans,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _green1,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reports & Analysis',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Last updated: just now',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  FILTER ROW  — functional Species & Health filters
  // ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Filters label chip (decorative) ────────────────
            _filterChip(
              label: 'Filters',
              icon: Icons.filter_list,
              isActive: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),

            // ── Species dropdown ────────────────────────────────
            GestureDetector(
              onTap: () => _showSpeciesSheet(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedSpecies != null ? _green1 : _bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedSpecies != null
                        ? _green1
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedSpecies ?? 'Species',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _selectedSpecies != null
                            ? Colors.white
                            : const Color(0xFF4A6350),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down,
                        size: 14,
                        color: _selectedSpecies != null
                            ? Colors.white
                            : const Color(0xFF4A6350)),
                    if (_selectedSpecies != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _applyFilter(clearSpecies: true),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Health dropdown ─────────────────────────────────
            GestureDetector(
              onTap: () => _showHealthSheet(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedHealth != null ? _green1 : _bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedHealth != null
                        ? _green1
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedHealth ?? 'Health',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _selectedHealth != null
                            ? Colors.white
                            : const Color(0xFF4A6350),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down,
                        size: 14,
                        color: _selectedHealth != null
                            ? Colors.white
                            : const Color(0xFF4A6350)),
                    if (_selectedHealth != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _applyFilter(clearHealth: true),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Species bottom sheet ────────────────────────────────────
  void _showSpeciesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter by Species',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const Spacer(),
                if (_selectedSpecies != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilter(clearSpecies: true);
                    },
                    child:
                        const Text('Clear', style: TextStyle(color: _orange)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allSpecies.map((sp) {
                final active = _selectedSpecies == sp;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _applyFilter(species: sp);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _green1 : _bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? _green1 : Colors.grey.shade300),
                    ),
                    child: Text(sp,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : _dark)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Health bottom sheet ─────────────────────────────────────
  void _showHealthSheet() {
    final options = [
      {'label': 'Healthy', 'icon': Icons.favorite, 'color': _green3},
      {'label': 'Unhealthy', 'icon': Icons.warning_amber, 'color': _orange},
      {
        'label': 'Recovering',
        'icon': Icons.healing,
        'color': Colors.blue.shade400
      },
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter by Health',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const Spacer(),
                if (_selectedHealth != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilter(clearHealth: true);
                    },
                    child:
                        const Text('Clear', style: TextStyle(color: _orange)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final label = opt['label'] as String;
              final icon = opt['icon'] as IconData;
              final color = opt['color'] as Color;
              final active = _selectedHealth == label;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter(health: label);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? color.withValues(alpha: 0.12) : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: active ? color : Colors.grey.shade200,
                        width: active ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: active ? color : _dark)),
                      const Spacer(),
                      if (active)
                        Icon(Icons.check_circle, color: color, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Decorative filter chip ──────────────────────────────────
  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _green1 : _bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _green1 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isActive ? Colors.white : const Color(0xFF4A6350)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : const Color(0xFF4A6350))),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  YIELD OVERVIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildYieldOverview({
    required int total,
    required double totalYield,
    required double avgYield,
    required String topTree,
    required double topYieldKg,
  }) {
    final totalStr = totalYield >= 1000
        ? '${(totalYield / 1000).toStringAsFixed(1)}k kg'
        : '${totalYield.toStringAsFixed(0)} kg';
    final farmerStr = totalYield >= 1000
        ? '${(totalYield * 5.5 / 1000).toStringAsFixed(1)}k kg'
        : '${(totalYield * 5.5).toStringAsFixed(0)} kg';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.eco_outlined, 'Yield Overview',
              iconColor: _green2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _yieldBox(
                      '🌿', 'Total Yield\n(All Trees)', totalStr, _bg)),
              const SizedBox(width: 8),
              Expanded(
                  child: _yieldBox('🌳', 'Avg Yield\nper Tree',
                      '${avgYield.toStringAsFixed(0)} kg', _bg)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _yieldBox('🏆', 'Highest\nYield Tree', topTree,
                      const Color(0xFFE8F5E9),
                      sub: '${topYieldKg.toStringAsFixed(0)} kg',
                      subColor: _dark)),
              const SizedBox(width: 8),
              Expanded(
                  child: _yieldBox('📊', 'Farmer\nTotal Yield', farmerStr,
                      const Color(0xFFFFF8E1),
                      sub: '($total trees)',
                      subColor: const Color(0xFF9A7A35))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yieldBox(String emoji, String label, String value, Color bg,
      {String? sub, Color? subColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF8FAF96), height: 1.3)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _dark)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 9, color: subColor ?? _sub)),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEALTH DISTRIBUTION — animated donut chart
  // ─────────────────────────────────────────────────────────────
  Widget _buildHealthDistCard({
    required int total,
    required int healthy,
    required int unhealthy,
    required int recovering,
    required int todayScans,
    required int weekScans,
  }) {
    final pct = total > 0 ? (healthy / total * 100).round() : 0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health dist.',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 10),

          // ── Donut chart ───────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pieAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(90, 90),
                painter: _DonutPainter(
                  healthy: healthy,
                  unhealthy: unhealthy,
                  recovering: recovering,
                  total: total,
                  progress: _pieAnim.value,
                  pct: pct,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Legend ────────────────────────────────────────────
          _legend(const Color(0xFF4E9B64), 'Healthy', healthy),
          const SizedBox(height: 4),
          _legend(_orange, 'Unhealthy', unhealthy),
          const SizedBox(height: 4),
          _legend(_green4, 'Recovering', recovering),
          const SizedBox(height: 10),

          // ── Scan counts ───────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          _scanRow('Scans today', todayScans),
          const SizedBox(height: 4),
          _scanRow('Scans this week', weekScans),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, int count) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF4A6350))),
        ),
        Text('$count',
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: _dark)),
      ],
    );
  }

  Widget _scanRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _sub)),
        Text('$value',
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _dark)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  AGE DISTRIBUTION — animated bar chart
  // ─────────────────────────────────────────────────────────────
  Widget _buildAgeDistCard({
    required int age0to1,
    required int age1to5,
    required int age5plus,
    required int todayScans,
    required int weekScans,
  }) {
    final maxAge =
        [age0to1, age1to5, age5plus].fold(0, (m, v) => v > m ? v : m);

    final bars = [
      _BarData(label: '0–1', value: age0to1, maxValue: maxAge, color: _green4),
      _BarData(label: '1–5', value: age1to5, maxValue: maxAge, color: _green3),
      _BarData(label: '5+', value: age5plus, maxValue: maxAge, color: _green2),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Age dist.',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 10),

          // ── Bar chart ─────────────────────────────────────────
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: _ageBarAnim,
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars
                    .map((b) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${b.value}',
                                    style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: _dark)),
                                const SizedBox(height: 2),
                                AnimatedContainer(
                                  duration: Duration.zero,
                                  child: Container(
                                    width: double.infinity,
                                    height: b.maxValue == 0
                                        ? 2
                                        : (b.value / b.maxValue * 72) *
                                            _ageBarAnim.value,
                                    decoration: BoxDecoration(
                                      color: b.color,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(b.label,
                                    style: const TextStyle(
                                        fontSize: 8, color: _sub)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          _scanRow('Scans today', todayScans),
          const SizedBox(height: 4),
          _scanRow('Scans this week', weekScans),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WEEKLY SCAN TREND — animated bar chart
  // ─────────────────────────────────────────────────────────────
  Widget _buildWeeklyTrendCard({required List<int> weekCounts}) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = weekCounts.fold(0, (m, v) => v > m ? v : m);
    final today = DateTime.now().weekday - 1; // 0=Mon … 6=Sun

    // Growth % vs previous week (simulated)
    final thisWeek = weekCounts.fold(0, (a, b) => a + b);
    final pctLabel = '+${(thisWeek * 0.12).round()}% this week';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Weekly scan trend',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
              Text(pctLabel,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _green3)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: AnimatedBuilder(
              animation: _weekBarAnim,
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = weekCounts[i];
                  final isToday = i == today;
                  final barH = maxVal == 0
                      ? 2.0
                      : (val / maxVal * 54) * _weekBarAnim.value;
                  final color = isToday
                      ? _green1
                      : val > maxVal * 0.6
                          ? _green3
                          : _green5;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isToday)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _green1,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('$val',
                                    style: const TextStyle(
                                        fontSize: 7,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          Container(
                            height: barH.clamp(2.0, 54.0),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(days[i],
                              style: TextStyle(
                                  fontSize: 8,
                                  color: isToday ? _green1 : _sub,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  RFID ACTIVITY
  // ─────────────────────────────────────────────────────────────
  Widget _buildRFIDActivityCard({
    required int todayScans,
    required int weekScans,
  }) {
    final activities = [
      {'name': 'Apple Tree #12', 'time': '10 min ago'},
      {'name': 'Orange Tree #8', 'time': '30 min ago'},
      {'name': 'Pine Tree #25', 'time': '1 hr ago'},
      {'name': 'Jackfruit Tree #3', 'time': 'Yesterday'},
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: _orange, size: 16),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('RFID Activity',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      const TextSpan(
                          text: 'Today: ',
                          style: TextStyle(fontSize: 9, color: _sub)),
                      TextSpan(
                          text: '$todayScans',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                    ]),
                  ),
                  RichText(
                    text: TextSpan(children: [
                      const TextSpan(
                          text: 'Week: ',
                          style: TextStyle(fontSize: 9, color: _sub)),
                      TextSpan(
                          text: '$weekScans',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.asMap().entries.map((e) {
            final a = e.value;
            final isOld = a['time']!.contains('Yesterday');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner,
                        color: _orange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['name']!,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _dark)),
                        Text(a['time']!,
                            style: const TextStyle(fontSize: 10, color: _sub)),
                      ],
                    ),
                  ),
                  Text('${a['time']!} ›',
                      style: TextStyle(
                          fontSize: 10,
                          color: isOld ? _sub : _green3,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4D2B).withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title,
      {Color iconColor = _green2}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DONUT CHART PAINTER
// ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final int healthy;
  final int unhealthy;
  final int recovering;
  final int total;
  final double progress; // 0.0 → 1.0 (animation)
  final int pct;

  _DonutPainter({
    required this.healthy,
    required this.unhealthy,
    required this.recovering,
    required this.total,
    required this.progress,
    required this.pct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 2;
    const stroke = 22.0;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Proportions
    final tot = total == 0 ? 1 : total;
    final hAngle = (healthy / tot) * 2 * math.pi * progress;
    final uAngle = (unhealthy / tot) * 2 * math.pi * progress;
    final rAngle = (recovering / tot) * 2 * math.pi * progress;

    // Background ring (grey when nothing)
    if (total == 0) {
      final bgPaint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    }

    // Draw each arc segment
    double startAngle = -math.pi / 2;

    void drawArc(double sweep, Color color) {
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep - 0.04, false, paint);
      startAngle += sweep;
    }

    drawArc(hAngle, const Color(0xFF4E9B64));
    drawArc(uAngle, const Color(0xFFE07B2A));
    drawArc(rAngle, const Color(0xFFA5D6A7));

    // Centre hole fill
    final holePaint = Paint()
      ..color = const Color(0xFFF7F5F0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius - stroke / 2, holePaint);

    // Centre text
    final textPainter = TextPainter(
      text: TextSpan(
        text: total == 0 ? '0%' : '$pct%',
        style: const TextStyle(
          color: Color(0xFF1A2E1C),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.healthy != healthy ||
      old.unhealthy != unhealthy ||
      old.recovering != recovering;
}

// ─────────────────────────────────────────────────────────────
//  BAR DATA MODEL
// ─────────────────────────────────────────────────────────────
class _BarData {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  const _BarData({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });
}

// ============================================================
//  lib/features/rfid/rfid_scan_screen.dart   (NEW FILE)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../data/models/tree_model.dart';
import 'rfid_tree_detail_screen.dart';

// ── States the scan screen moves through ─────────────────────────────────────
enum _ScanState { idle, connecting, scanning, detected, notFound }

class RFIDScanScreen extends StatefulWidget {
  const RFIDScanScreen({super.key});

  @override
  State<RFIDScanScreen> createState() => _RFIDScanScreenState();
}

class _RFIDScanScreenState extends State<RFIDScanScreen>
    with TickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;

  // Pulse rings that expand outward while scanning
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Spinning icon while connecting / scanning
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.82, end: 1.55).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _spinAnim = Tween<double>(begin: 0, end: 1).animate(_spinCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  // ── Full scan flow triggered by tapping the big button ─────────────────────
  Future<void> _onScanPressed() async {
    if (_state != _ScanState.idle && _state != _ScanState.notFound) return;

    HapticFeedback.mediumImpact();

    // ── Step 1: Connecting ──
    setState(() => _state = _ScanState.connecting);
    _pulseCtrl.repeat();
    _spinCtrl.repeat();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // ── Step 2: Scanning ──
    setState(() => _state = _ScanState.scanning);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // ── Step 3: Pick a random mock RFID tag (simulates machine sending a tag) ──
    final tags = mockTrees.map((t) => t.rfidTag).toList()..shuffle();
    final detectedTag = tags.first;

    // ── Step 4: Tag detected feedback ──
    HapticFeedback.heavyImpact();
    setState(() => _state = _ScanState.detected);
    _pulseCtrl.stop();
    _spinCtrl.stop();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // ── Step 5: Check REAL internet connectivity ──
    final connectivity = await Connectivity().checkConnectivity();
    final bool isOnline = connectivity != ConnectivityResult.none;

    // ── Step 6: Look up matching tree ──
    Tree? tree;
    try {
      tree = mockTrees.firstWhere((t) => t.rfidTag == detectedTag);
    } catch (_) {
      setState(() => _state = _ScanState.notFound);
      return;
    }

    // ── Step 7: Navigate to TreeDetailScreen ──
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TreeDetailScreen(
          tree: tree!,
          dataSource: isOnline ? 'cloud' : 'local',
        ),
      ),
    );
  }

  // ── Reset back to idle ──────────────────────────────────────────────────────
  // ignore: unused_element
  void _reset() {
    _pulseCtrl
      ..stop()
      ..reset();
    _spinCtrl
      ..stop()
      ..reset();
    setState(() => _state = _ScanState.idle);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  bool get _isActive =>
      _state == _ScanState.connecting || _state == _ScanState.scanning;

  String get _buttonLabel => switch (_state) {
        _ScanState.idle => 'SCAN',
        _ScanState.connecting => 'CONNECTING',
        _ScanState.scanning => 'SCANNING',
        _ScanState.detected => 'FOUND!',
        _ScanState.notFound => 'RETRY',
      };

  String get _statusText => switch (_state) {
        _ScanState.idle =>
          'Hold device near RFID tag,\nthen press SCAN',
        _ScanState.connecting => 'Connecting to RFID reader...',
        _ScanState.scanning => 'Scanning for tags...',
        _ScanState.detected => 'Tag detected! Loading tree data...',
        _ScanState.notFound => 'No tree found for this tag. Try again.',
      };

  Color get _accentColor => switch (_state) {
        _ScanState.idle => Colors.green.shade700,
        _ScanState.connecting => Colors.blue.shade700,
        _ScanState.scanning => Colors.green.shade700,
        _ScanState.detected => Colors.green.shade800,
        _ScanState.notFound => Colors.red.shade600,
      };

  IconData get _centerIcon => switch (_state) {
        _ScanState.idle => Icons.qr_code_scanner,
        _ScanState.connecting => Icons.wifi_tethering_rounded,
        _ScanState.scanning => Icons.radar_rounded,
        _ScanState.detected => Icons.check_circle_rounded,
        _ScanState.notFound => Icons.error_outline_rounded,
      };

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'RFID Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // Down arrow to dismiss
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Status banner ──
            _buildStatusBanner(),

            // ── Big scan button (centred in remaining space) ──
            Expanded(
              child: Center(child: _buildScanButton()),
            ),

            // ── Bottom hint row ──
            _buildBottomHints(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Status banner at top ────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _state == _ScanState.detected
                ? Icons.check_circle_outline
                : _state == _ScanState.notFound
                    ? Icons.error_outline
                    : Icons.info_outline,
            color: _accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _statusText,
                key: ValueKey(_state),
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (_isActive)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: _accentColor,
              ),
            ),
        ],
      ),
    );
  }

  // ── Pulsing rings + big scan button ─────────────────────────────────────────
  Widget _buildScanButton() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          if (_isActive)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.10),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // Middle pulse ring
          if (_isActive)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value * 0.78,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.20),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // Fixed white ring (always visible)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.22),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.10),
                  blurRadius: 28,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // ── THE BIG SCAN BUTTON ──
          GestureDetector(
            onTap: (_state == _ScanState.idle || _state == _ScanState.notFound)
                ? _onScanPressed
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _accentColor,
                    _accentColor.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: _isActive ? 0.45 : 0.28),
                    blurRadius: _isActive ? 36 : 18,
                    spreadRadius: _isActive ? 6 : 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spin icon when active, static otherwise
                  _isActive
                      ? RotationTransition(
                          turns: _spinAnim,
                          child: Icon(_centerIcon,
                              color: Colors.white, size: 46),
                        )
                      : Icon(_centerIcon, color: Colors.white, size: 46),

                  const SizedBox(height: 8),

                  Text(
                    _buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom hint chips ───────────────────────────────────────────────────────
  Widget _buildBottomHints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _HintChip(
            icon: Icons.wifi_rounded,
            label: 'Auto detects\nnetwork',
            color: Colors.blue.shade600,
          ),
          _HintChip(
            icon: Icons.cloud_sync_rounded,
            label: 'Cloud or\nlocal data',
            color: Colors.green.shade700,
          ),
          _HintChip(
            icon: Icons.park_rounded,
            label: 'Instant\ntree info',
            color: Colors.orange.shade700,
          ),
        ],
      ),
    );
  }
}

// ── Small hint chip ───────────────────────────────────────────────────────────
class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
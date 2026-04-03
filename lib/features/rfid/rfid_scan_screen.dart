// ============================================================
//  lib/features/rfid/rfid_scan_screen.dart   (NEW FILE)
// ============================================================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'rfid_service.dart';
import 'tag_protocol.dart';

// ── States the scan screen moves through ─────────────────────────────────────
enum _ScanState {
  idle,
  scanningDevices,
  connectingDevice,
  connectedWaitingTag,
  scanningTag,
  tagReady,
  reading,
  writing,
  notFound,
}

class RFIDScanScreen extends StatefulWidget {
  const RFIDScanScreen({super.key});

  @override
  State<RFIDScanScreen> createState() => _RFIDScanScreenState();
}

class _RFIDScanScreenState extends State<RFIDScanScreen>
    with TickerProviderStateMixin {
  static String? _rememberedDeviceAddress;
  static String? _rememberedDeviceName;

  _ScanState _state = _ScanState.idle;

  final RfidService _rfid = RfidService();
  String? _selectedDeviceAddress;
  String? _selectedDeviceName;
  String _lastScannedEpc = '';
  final List<String> _scannedTagHistory = <String>[];
  final Map<String, TagData> _tagDataByEpc = <String, TagData>{};
  TagData? _lastTagData;
  bool _tagHasUserData = false;

  // Applied reader session settings (must be re-confirmed after every connect).
  int _sessionFrequencyMode = 0x04; // EU default
  bool _sessionMultiTagMode = false; // Single default
  bool _sessionSetupDone = false;

  int _epcCounter = 0;

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

    // If we already connected to a reader earlier, don't re-scan devices.
    // The reader address will be reused, and "SCAN TAG" will be available.
    if (_rememberedDeviceAddress != null &&
        _rememberedDeviceAddress!.isNotEmpty) {
      _selectedDeviceAddress = _rememberedDeviceAddress;
      _selectedDeviceName = _rememberedDeviceName;
      _state = _ScanState.connectedWaitingTag;
      _sessionSetupDone = false; // Force setup again on next scan.
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  // ── Full scan flow triggered by tapping the big button ─────────────────────
  Future<void> _onScanPressed() async {
    // If we are connected already, this button must scan the TAG.
    if (_state == _ScanState.connectedWaitingTag) {
      final rememberedAddr = _selectedDeviceAddress;
      if (rememberedAddr == null || rememberedAddr.isEmpty) {
        setState(() => _state = _ScanState.notFound);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No reader selected. Please scan again.')),
        );
        return;
      }

      // Ensure we really reconnect for this session (important after reopening screen).
      setState(() => _state = _ScanState.connectingDevice);
      _pulseCtrl.repeat();
      _spinCtrl.repeat();
      final reconnected = await _rfid.connectDevice(rememberedAddr);
      if (!mounted) return;
      _pulseCtrl.stop();
      _spinCtrl.stop();
      if (!reconnected) {
        setState(() => _state = _ScanState.notFound);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not reconnect to reader. Press SCAN to discover again.'),
          ),
        );
        return;
      }

      setState(() => _state = _ScanState.connectedWaitingTag);

      if (!_sessionSetupDone) {
        final bool configured = await _showReaderSetupDialog();
        if (!configured) {
          if (!mounted) return;
          setState(() => _state = _ScanState.notFound);
          return;
        }
        if (!mounted) return;
        setState(() => _sessionSetupDone = true);
      }
      await _scanTagFromReader();
      return;
    }

    // Otherwise, connect to a reader (scan devices first).
    if (_state != _ScanState.idle && _state != _ScanState.notFound) return;

    setState(() {
      _selectedDeviceAddress = null;
      _lastScannedEpc = '';
      _lastTagData = null;
      _tagHasUserData = false;
      _sessionSetupDone = false;
    });

    // ── Runtime permissions (Android 12+ requires these) ───────────────
    final permissions = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final bool granted =
        permissions[Permission.bluetoothConnect] == PermissionStatus.granted &&
            permissions[Permission.bluetoothScan] == PermissionStatus.granted;

    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please allow Bluetooth permissions to connect to the reader.',
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // ── Step 1: Check Bluetooth enabled ──
    final bool btEnabled = await _rfid.isBluetoothEnabled();
    if (!btEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turn ON Bluetooth to continue.'),
        ),
      );
      setState(() => _state = _ScanState.notFound);
      return;
    }

    // ── Step 2: Scan BLE devices ──
    setState(() => _state = _ScanState.scanningDevices);
    _pulseCtrl.repeat();
    _spinCtrl.repeat();

    final devices = await _rfid.scanBleDevices(timeoutMs: 15000);
    if (!mounted) return;

    if (devices.isEmpty) {
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.notFound);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Bluetooth devices found. Bring the reader closer and try again.',
          ),
        ),
      );
      return;
    }

    final selectedDevice = await _showDevicePickerDialog(devices);
    if (!mounted) return;
    if (selectedDevice == null) {
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.idle);
      return;
    }

    final String chosenAddress = selectedDevice['address'] ?? '';
    final String chosenName = selectedDevice['name'] ?? '';

    if (chosenAddress.isEmpty) {
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.notFound);
      return;
    }

    // ── Step 3: Connect to chosen device ──
    setState(() {
      _selectedDeviceAddress = chosenAddress;
      _selectedDeviceName = chosenName;
      _state = _ScanState.connectingDevice;
    });

    final bool ok = await _rfid.connectDevice(chosenAddress);
    if (!mounted) return;

    if (!ok) {
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.notFound);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to the RFID reader. Try again.'),
        ),
      );
      return;
    }

    _pulseCtrl.stop();
    _spinCtrl.stop();
    _rememberedDeviceAddress = chosenAddress;
    _rememberedDeviceName = chosenName;

    final bool configured = await _showReaderSetupDialog();
    if (!mounted) return;
    if (!configured) {
      setState(() => _state = _ScanState.notFound);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reader setup is required after every connection.'),
        ),
      );
      return;
    }
    setState(() => _sessionSetupDone = true);

    // IMPORTANT: only after TAG scan we show READ/WRITE.
    setState(() => _state = _ScanState.connectedWaitingTag);
    HapticFeedback.heavyImpact();
  }

  Future<bool> _showReaderSetupDialog() async {
    int frequencyMode = 0x04; // EU default
    bool multiTagMode = false; // Single default

    final bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Scanner Setup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select frequency region'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: frequencyMode,
                    items: const [
                      DropdownMenuItem(
                          value: 0x04, child: Text('Europe (0x04)')),
                      DropdownMenuItem(
                          value: 0x08, child: Text('United States (0x08)')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => frequencyMode = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Tag scanning mode'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<bool>(
                    initialValue: multiTagMode,
                    items: const [
                      DropdownMenuItem(value: false, child: Text('Single tag')),
                      DropdownMenuItem(value: true, child: Text('Multi tag')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => multiTagMode = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );

    if (accepted != true) return false;
    final ok = await _rfid.configureReaderSession(
      frequencyMode: frequencyMode,
      multiTagMode: multiTagMode,
    );
    if (!ok) return false;

    // Persist settings for banner + for the current connected session.
    if (mounted) {
      setState(() {
        _sessionFrequencyMode = frequencyMode;
        _sessionMultiTagMode = multiTagMode;
      });
    }
    return true;
  }

  Future<Map<String, String>?> _showDevicePickerDialog(
    List<Map<String, String>> devices,
  ) async {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select RFID Scanner'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: devices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = devices[i];
                final name = (d['name'] ?? '').trim().isEmpty
                    ? 'Unknown Device'
                    : d['name']!;
                final addr = d['address'] ?? '';
                return ListTile(
                  dense: true,
                  title:
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(addr),
                  onTap: () => Navigator.pop(ctx, d),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  bool _hasValidUserData(TagData data) {
    final name = data.farmerName.trim();
    return name.isNotEmpty ||
        data.healthStatus != HealthStatus.unknown ||
        data.lastInspectionUnix != 0 ||
        data.lastYieldKg != 0.0 ||
        data.treeAgeYears != 0;
  }

  Future<void> _scanTagFromReader() async {
    final deviceAddress = _selectedDeviceAddress;
    if (deviceAddress == null || deviceAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reader not connected. Press SCAN again.')),
      );
      setState(() => _state = _ScanState.notFound);
      return;
    }

    setState(() => _state = _ScanState.scanningTag);
    _pulseCtrl.repeat();
    _spinCtrl.repeat();

    Map<String, String> tagIdentity;
    try {
      tagIdentity = await _rfid.scanTagIdentity(
        deviceAddress: deviceAddress,
        timeoutMs: 7000,
      );
    } catch (_) {
      if (!mounted) return;
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.connectedWaitingTag);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tag detected. Press trigger and keep tag close.'),
        ),
      );
      return;
    }
    if (!mounted) return;

    final epcOnly = (tagIdentity['epc'] ?? '').trim();
    final tidOnly = (tagIdentity['tid'] ?? '').trim();
    if (epcOnly.isEmpty) {
      _pulseCtrl.stop();
      _spinCtrl.stop();
      setState(() => _state = _ScanState.connectedWaitingTag);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tag not recognized. Press trigger and try again.'),
        ),
      );
      return;
    }
    setState(() => _lastScannedEpc = epcOnly);
    _addToTagHistory(epcOnly);

    Map<String, String> payload = <String, String>{};
    try {
      // Try reading USER memory, but do not block popup flow if this fails.
      payload = await _rfid
          .readUserBank(deviceAddress: deviceAddress)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      payload = <String, String>{};
    }
    if (!mounted) return;

    _pulseCtrl.stop();
    _spinCtrl.stop();

    final userHex = payload['userHex'] ?? '';
    final epc = (payload['epc'] ?? epcOnly);
    final tid = (payload['tid'] ?? tidOnly);

    TagData tagData;
    try {
      if (userHex.isNotEmpty) {
        tagData = decodeTagData(
          userHex,
          verifyCrc: false,
          epc: epc,
          tid: tid,
        );
      } else {
        // EPC recognized but tag has no USER payload yet.
        tagData = TagData(
          epc: epc,
          tid: tid,
          treeId: epc,
          farmerName: '',
          lastInspectionUnix: 0,
          healthStatus: HealthStatus.unknown,
          lastYieldKg: 0,
          treeAgeYears: 0,
          species: Species.unknown,
        );
      }
    } catch (_) {
      tagData = TagData(
        epc: epc,
        tid: tid,
        treeId: epc,
        farmerName: '',
        lastInspectionUnix: 0,
        healthStatus: HealthStatus.unknown,
        lastYieldKg: 0,
        treeAgeYears: 0,
        species: Species.unknown,
      );
    }

    _lastTagData = tagData;
    _tagHasUserData = _hasValidUserData(tagData);
    _tagDataByEpc[epc.toUpperCase()] = tagData;

    setState(() => _state = _ScanState.tagReady);
    HapticFeedback.heavyImpact();
    await _showReadWriteChoiceDialog();
  }

  Future<void> _onReadPressed() async {
    TagData? tagData = _lastTagData;
    if (tagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press SCAN TAG first.')),
      );
      return;
    }

    if (!_tagHasUserData) {
      final cached = _tagDataByEpc[_lastScannedEpc.toUpperCase()];
      if (cached != null && _hasValidUserData(cached)) {
        tagData = cached;
        _lastTagData = cached;
        _tagHasUserData = true;
      }
    }

    setState(() => _state = _ScanState.reading);
    await _showReadTagDialog(tagData);
    if (!mounted) return;
    setState(() => _state = _ScanState.tagReady);
  }

  Future<void> _showReadTagDialog(TagData data) async {
    final hasUser = _hasValidUserData(data);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Read from Tag'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _readOnlyField('Tree ID (from EPC)', data.treeId),
                _readOnlyField('Tag EPC', data.epc.isEmpty ? '—' : data.epc),
                _readOnlyField('Tag TID', data.tid.isEmpty ? '—' : data.tid),
                const Divider(height: 24),
                if (!hasUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No user data stored on this tag yet.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _readOnlyField(
                  'Farmer Name / Owner',
                  hasUser && data.farmerName.trim().isNotEmpty
                      ? data.farmerName
                      : '—',
                ),
                _readOnlyField('Health Status', data.healthStatus.name),
                _readOnlyField('Species', data.species.name),
                _readOnlyField(
                  'Last Yield (kg)',
                  hasUser ? data.lastYieldKg.toStringAsFixed(1) : '—',
                ),
                _readOnlyField(
                  'Tree Age (years)',
                  hasUser ? '${data.treeAgeYears}' : '—',
                ),
                _readOnlyField(
                  'Last inspection',
                  data.lastInspectionUnix == 0
                      ? '—'
                      : DateTime.fromMillisecondsSinceEpoch(
                          data.lastInspectionUnix * 1000,
                        ).toString().split('.').first,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _addToTagHistory(String epc) {
    final normalized = epc.trim().toUpperCase();
    if (normalized.isEmpty) return;
    setState(() {
      _scannedTagHistory.remove(normalized);
      _scannedTagHistory.insert(0, normalized);
    });
  }

  Future<void> _showScannedHistoryDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Scanned Tag History'),
              content: SizedBox(
                width: double.maxFinite,
                child: _scannedTagHistory.isEmpty
                    ? const Text('No scanned tags yet.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _scannedTagHistory.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final epc = _scannedTagHistory[i];
                          return ListTile(
                            dense: true,
                            title: Text(epc),
                            onTap: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Selected tag: $epc')),
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: _scannedTagHistory.isEmpty
                      ? null
                      : () {
                          setState(() => _scannedTagHistory.clear());
                          setLocal(() {});
                        },
                  child: const Text('DELETE HISTORY'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CLOSE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onWritePressed() async {
    final deviceAddress = _selectedDeviceAddress;
    final base = _lastTagData;

    if (deviceAddress == null || deviceAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to the reader first.')),
      );
      return;
    }
    if (base == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press SCAN TAG first.')),
      );
      return;
    }

    setState(() => _state = _ScanState.writing);

    final newEpcHex = _generateNewEpcHex12B();
    final TagData? updated = await _showWriteDialog(
      initial: base,
      newEpcHex: newEpcHex,
      prefillUserData: _tagHasUserData,
    );
    if (updated == null) {
      if (!mounted) return;
      setState(() => _state = _ScanState.tagReady);
      return;
    }

    final hex = encodeTagData(updated);
    bool ok = false;
    try {
      ok = await _rfid.writeUserBank(
        deviceAddress: deviceAddress,
        hexUserBank: hex,
        newEpcHex: newEpcHex,
      );
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    _lastTagData = updated;
    _tagHasUserData = true;
    if (_lastScannedEpc.isNotEmpty) {
      _tagDataByEpc[_lastScannedEpc.toUpperCase()] = updated;
    }
    setState(() => _state = _ScanState.tagReady);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Tag written successfully.' : 'Write failed.'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  String _generateNewEpcHex12B() {
    // 12 bytes (96-bit) EPC. Use time + increment + secure random.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final counter = (_epcCounter++ & 0xFFFFFFFF);

    final bytes = Uint8List(12);
    // first 8 bytes: millis (big-endian)
    for (var i = 0; i < 8; i++) {
      bytes[i] = (nowMs >> (56 - 8 * i)) & 0xFF;
    }
    // next 4 bytes: counter (big-endian)
    for (var i = 0; i < 4; i++) {
      bytes[8 + i] = (counter >> (24 - 8 * i)) & 0xFF;
    }
    // mix in a little randomness
    final rnd = Random.secure();
    for (var i = 0; i < 12; i++) {
      bytes[i] = bytes[i] ^ rnd.nextInt(256);
    }
    return bytesToHex(bytes); // 24 hex chars
  }

  Future<void> _showReadWriteChoiceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:
              Text(_lastScannedEpc.isEmpty ? 'Tag Detected' : _lastScannedEpc),
          content: Text(
            _lastScannedEpc.isEmpty
                ? 'Choose an action for this tag.'
                : 'Choose an action for this tag.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _onReadPressed();
              },
              child: const Text('READ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _onWritePressed();
              },
              child: const Text('WRITE'),
            ),
          ],
        );
      },
    );
  }

  Future<TagData?> _showWriteDialog({
    required String newEpcHex,
    TagData? initial,
    bool prefillUserData = true,
  }) async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final bool doPrefill = prefillUserData && initial != null;

    String farmerText = '';
    String yieldText = '';
    String ageText = '';
    HealthStatus health = HealthStatus.unknown;
    Species species = Species.unknown;
    double? yieldInput;
    int? ageInput;

    if (doPrefill) {
      // `doPrefill` implies `initial != null`
      farmerText = initial.farmerName;
      yieldText = initial.lastYieldKg.toStringAsFixed(1);
      ageText = initial.treeAgeYears.toString();
      health = initial.healthStatus;
      species = initial.species;
      yieldInput = initial.lastYieldKg;
      ageInput = initial.treeAgeYears;
    }

    final farmerController = TextEditingController(text: farmerText);
    final yieldController = TextEditingController(text: yieldText);
    final ageController = TextEditingController(text: ageText);

    return showDialog<TagData>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Write to Tag (USER memory)'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: farmerController,
                      decoration: const InputDecoration(
                        labelText: 'Farmer Name / Owner',
                        hintText: 'R. Kumar',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<HealthStatus>(
                      initialValue: health,
                      decoration: const InputDecoration(
                        labelText: 'Health Status',
                      ),
                      items: HealthStatus.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => health = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Species>(
                      initialValue: species,
                      decoration: const InputDecoration(
                        labelText: 'Species',
                      ),
                      items: Species.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => species = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Last Yield (kg)',
                        hintText: '10.5',
                      ),
                      controller: yieldController,
                      onChanged: (s) {
                        final t = s.trim();
                        if (t.isEmpty) {
                          setLocal(() => yieldInput = null);
                          return;
                        }
                        final parsed = double.tryParse(t.replaceAll(',', '.'));
                        if (parsed == null) return;
                        setLocal(() => yieldInput = parsed);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tree Age (years)',
                        hintText: '6',
                      ),
                      controller: ageController,
                      onChanged: (s) {
                        final t = s.trim();
                        if (t.isEmpty) {
                          setLocal(() => ageInput = null);
                          return;
                        }
                        final parsed = int.tryParse(t);
                        if (parsed == null) return;
                        setLocal(() => ageInput = parsed);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Last inspection date will be set to now.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final farmerName = farmerController.text.trim();
                    if (farmerName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Farmer name is required.')),
                      );
                      return;
                    }
                    if (yieldInput == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Last yield is required.')),
                      );
                      return;
                    }
                    if (ageInput == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tree age is required.')),
                      );
                      return;
                    }
                    try {
                      final data = TagData(
                        treeId: newEpcHex,
                        epc: newEpcHex,
                        tid: initial?.tid ?? '',
                        farmerName: farmerName,
                        lastInspectionUnix: nowUnix,
                        healthStatus: health,
                        lastYieldKg: yieldInput!,
                        treeAgeYears: ageInput!,
                        species: species,
                      );
                      Navigator.pop(ctx, data);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid input: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('WRITE'),
                ),
              ],
            );
          },
        );
      },
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
      _state == _ScanState.scanningDevices ||
      _state == _ScanState.connectingDevice ||
      _state == _ScanState.scanningTag ||
      _state == _ScanState.writing;

  String get _buttonLabel => switch (_state) {
        _ScanState.idle => 'SCAN',
        _ScanState.scanningDevices => 'SCANNING',
        _ScanState.connectingDevice => 'CONNECTING',
        _ScanState.connectedWaitingTag => 'SCAN TAG',
        _ScanState.scanningTag => 'SCANNING TAG',
        _ScanState.tagReady => 'TAG READY',
        _ScanState.reading => 'READING',
        _ScanState.writing => 'WRITING',
        _ScanState.notFound => 'RETRY',
      };

  String get _statusText => switch (_state) {
        _ScanState.idle => 'Press SCAN to connect to the RFID reader',
        _ScanState.scanningDevices => 'Scanning for Bluetooth devices...',
        _ScanState.connectingDevice => 'Connecting to RFID reader...',
        _ScanState.connectedWaitingTag => 'Reader connected. Tap SCAN TAG.',
        _ScanState.scanningTag => 'Scanning tag and reading USER memory...',
        _ScanState.tagReady => _tagHasUserData
            ? 'Tag data loaded. Choose READ or WRITE.'
            : 'No data available in tag. WRITE is empty.',
        _ScanState.reading => 'Opening tag data...',
        _ScanState.writing => 'Writing tag USER memory...',
        _ScanState.notFound => 'No reader found. Try again.',
      };

  Color get _accentColor => switch (_state) {
        _ScanState.idle => Colors.green.shade700,
        _ScanState.scanningDevices => Colors.blue.shade700,
        _ScanState.connectingDevice => Colors.blue.shade700,
        _ScanState.connectedWaitingTag => Colors.green.shade800,
        _ScanState.scanningTag => Colors.green.shade800,
        _ScanState.tagReady => Colors.green.shade800,
        _ScanState.reading => Colors.green.shade800,
        _ScanState.writing => Colors.orange.shade700,
        _ScanState.notFound => Colors.red.shade600,
      };

  IconData get _centerIcon => switch (_state) {
        _ScanState.idle => Icons.search_rounded,
        _ScanState.scanningDevices => Icons.bluetooth_rounded,
        _ScanState.connectingDevice => Icons.wifi_tethering_rounded,
        _ScanState.connectedWaitingTag => Icons.qr_code_scanner_rounded,
        _ScanState.scanningTag => Icons.radar_rounded,
        _ScanState.tagReady => Icons.check_circle_rounded,
        _ScanState.reading => Icons.download_rounded,
        _ScanState.writing => Icons.upload_rounded,
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
        actions: [
          IconButton(
            tooltip: 'Scanned Tag History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showScannedHistoryDialog,
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _state == _ScanState.tagReady
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
          if (_selectedDeviceAddress != null &&
              _selectedDeviceAddress!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: Text(
                'Reader: ${_selectedDeviceName ?? 'Unknown'}',
                style: TextStyle(
                  color: _accentColor.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_selectedDeviceAddress != null &&
              _selectedDeviceAddress!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                'Session: ${_sessionFrequencyMode == 0x04 ? 'Europe' : 'United States'}'
                ' (${_sessionFrequencyMode == 0x04 ? '0x04' : '0x08'})'
                ' | ${_sessionMultiTagMode ? 'Multi' : 'Single'}',
                style: TextStyle(
                  color: _accentColor.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
            onTap: (_state == _ScanState.idle ||
                    _state == _ScanState.notFound ||
                    _state == _ScanState.connectedWaitingTag)
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
                    color:
                        _accentColor.withValues(alpha: _isActive ? 0.45 : 0.28),
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
                          child:
                              Icon(_centerIcon, color: Colors.white, size: 46),
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
    if (_state == _ScanState.tagReady) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            const Text(
              'Tag ready. Choose action:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onReadPressed,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('READ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onWritePressed,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('WRITE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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

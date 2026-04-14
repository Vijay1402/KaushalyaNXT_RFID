import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../data/models/tree_model.dart';
import 'tree_controller.dart';
import '../../rfid/rfid_scan_screen.dart';
import 'tree_history_screen.dart';
import 'tree_map_screen.dart';
import 'tree_photos_screen.dart';
import 'tree_predictions_screen.dart';
import 'tree_weather_screen.dart';

class TreeDetailScreen extends ConsumerStatefulWidget {
  final String treeId;
  final String source;

  const TreeDetailScreen({
    super.key,
    required this.treeId,
    this.source = 'myTrees',
  });

  @override
  ConsumerState<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends ConsumerState<TreeDetailScreen> {
  bool _locationBackfillStarted = false;
  ProviderSubscription<AsyncValue<bool>>? _connectivitySubscription;
  final Map<String, Future<Map<String, dynamic>?>> _tagDataFutures = {};

  @override
  void initState() {
    super.initState();
    _tagDataFutures.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treeIssueControllerProvider).syncPendingIssues();
    });
    _connectivitySubscription = ref.listenManual<AsyncValue<bool>>(
      connectivityStatusProvider,
      (_, next) {
        if (next.value == true) {
          ref.read(treeIssueControllerProvider).syncPendingIssues();
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.close();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadTagData(
    Map<String, dynamic> treeData, {
    required bool isOnline,
  }) async {
    final firebaseUser = ref.read(authServiceProvider).getCurrentUser();
    final userId = firebaseUser?.uid ?? '';
    if (userId.isEmpty) return null;

    final cache = LocalCacheService();
    final treeId = (treeData['treeId'] ?? '').toString().trim();
    final rfid = (treeData['rfid'] ?? treeDocIdOf(treeData))
        .toString()
        .trim()
        .toUpperCase();

    if (isOnline) {
      final tagMap = tagSnapshotFromTree(treeData);
      if (tagMap != null && rfid.isNotEmpty) {
        await cache.saveWrittenTag(userId, tagMap);
        return tagMap;
      }
    }

    final localTag = await cache.getWrittenTagByTreeId(userId, treeId);
    if (localTag != null) {
      return localTag;
    }
    if (rfid.isEmpty) {
      return null;
    }
    return cache.getWrittenTagByEpc(userId, rfid);
  }

  Future<Map<String, dynamic>?> _getTagDataFuture(
    Map<String, dynamic> treeData, {
    required bool isOnline,
  }) {
    final key = [
      treeDocIdOf(treeData),
      (treeData['treeId'] ?? '').toString(),
      (treeData['rfid'] ?? '').toString(),
      (treeData['updatedAt'] ?? '').toString(),
      (treeData['lastinspectiondate'] ?? '').toString(),
      (treeData['healthStatus'] ?? '').toString(),
      (treeData['lastYieldKg'] ?? '').toString(),
      isOnline ? 'online' : 'offline',
    ].join('|');
    return _tagDataFutures.putIfAbsent(
      key,
      () => _loadTagData(
        treeData,
        isOnline: isOnline,
      ),
    );
  }

  String _tagHealthLabel(dynamic rawStatus) {
    final index = _asInt(rawStatus);
    switch (index) {
      case 1:
        return 'Healthy';
      case 2:
        return 'Needs Attention';
      case 3:
        return 'Diseased';
      case 4:
        return 'Dead';
      default:
        return 'Unknown';
    }
  }

  String _tagLastScanLabel(dynamic unixSeconds) {
    final seconds = _asInt(unixSeconds);
    if (seconds <= 0) return '-';
    return DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
    );
  }

  Future<File> _storeIssueImageLocally(XFile pickedFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final issueImagesDir = Directory('${appDir.path}/issue_reports');
    if (!await issueImagesDir.exists()) {
      await issueImagesDir.create(recursive: true);
    }

    final extension = pickedFile.path.contains('.')
        ? pickedFile.path.substring(pickedFile.path.lastIndexOf('.'))
        : '.jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTreeId = widget.treeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final storedFile = File(
      '${issueImagesDir.path}/${safeTreeId}_$timestamp$extension',
    );
    return File(pickedFile.path).copy(storedFile.path);
  }

  Future<void> _showIssueImageHistory({
    required String treeDocId,
    required String treeId,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final history = await ref
        .read(localCacheServiceProvider)
        .getIssueHistoryForTree(user.uid, treeDocId);
    final imageHistory = history.where((item) {
      return (item['localImagePath'] ?? '').toString().trim().isNotEmpty ||
          (item['imageUrl'] ?? '').toString().trim().isNotEmpty;
    }).toList(growable: false)
      ..sort((a, b) => (b['createdAtLocal'] ?? '')
          .toString()
          .compareTo((a['createdAtLocal'] ?? '').toString()));

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Issue Image History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tree: $treeId',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (imageHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No issue images saved yet.')),
                  )
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: imageHistory.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, index) {
                        final item = imageHistory[index];
                        final imagePath =
                            (item['localImagePath'] ?? '').toString().trim();
                        final imageUrl =
                            (item['imageUrl'] ?? '').toString().trim();
                        final imageFile =
                            imagePath.isEmpty ? null : File(imagePath);
                        final isSynced = imageUrl.isNotEmpty;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: imageFile != null &&
                                          imageFile.existsSync()
                                      ? Image.file(
                                          imageFile,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.grey.shade100,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSynced
                                            ? 'Stored in Firebase'
                                            : 'Only on device',
                                        style: TextStyle(
                                          color: isSynced
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (item['note'] ?? 'Issue photo')
                                            .toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportIssue({
    required String treeDocId,
    required String treeId,
    required String species,
    required String healthStatus,
    required String ownerName,
  }) async {
    final noteController = TextEditingController();
    File? pickedImage;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
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
                final storedImage = await _storeIssueImageLocally(picked);
                setSheet(() => pickedImage = storedImage);
              }
            }

            Future<void> submitIssue() async {
              final messenger = ScaffoldMessenger.of(context);
              if (isSubmitting) return;
              setSheet(() => isSubmitting = true);
              try {
                await ref.read(treeIssueControllerProvider).reportIssue(
                      treeDocId: treeDocId,
                      treeId: treeId,
                      species: species,
                      healthStatus: healthStatus,
                      ownerName: ownerName,
                      note: noteController.text,
                      imagePath: pickedImage?.path,
                    );
                if (!mounted || !ctx.mounted) return;
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Issue saved and will sync automatically.',
                    ),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to submit issue. Please try again.'),
                  ),
                );
                setSheet(() => isSubmitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Issue',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Issue Notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    if (pickedImage != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          pickedImage!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submitIssue,
                        child:
                            Text(isSubmitting ? 'Saving...' : 'Submit Issue'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Tree _buildTreeModel(Map<String, dynamic> data) {
    final plantingDate = _parseDate(
      data['plantingDate'] ?? data['plantedOn'] ?? data['createdAt'],
    );
    final lastInspection = _parseDate(
      data['lastinspectiondate'] ??
          data['lastInspectionDate'] ??
          data['updatedAt'],
    );

    return Tree(
      id: (data['treeId'] ?? 'No ID').toString(),
      name: (data['treeId'] ?? data['name'] ?? 'Tree').toString(),
      species: (data['species'] ?? 'Unknown species').toString(),
      plotNumber: (data['plotNumber'] ?? data['plot'] ?? '-').toString(),
      rfidTag: (data['rfid'] ?? data['rfidTag'] ?? 'No RFID').toString(),
      rfidTid: (data['rfidTid'] ?? '').toString(),
      plantingDate: plantingDate,
      currentStatus: _treeHealthStatusFromRaw(data['healthStatus']),
      lastInspectionDate: lastInspection,
      healthHistory: const [],
      maintenanceRecords: const [],
      photoUrls: const [],
      latitude: _asDouble(data['latitude']),
      longitude: _asDouble(data['longitude']),
      notes: (data['notes'] ?? '').toString(),
    );
  }

  TreeHealthStatus _treeHealthStatusFromRaw(dynamic status) {
    switch (status?.toString()) {
      case '0':
      case 'healthy':
      case 'Healthy':
        return TreeHealthStatus.healthy;
      case '1':
      case 'needsAttention':
      case 'Needs Attention':
        return TreeHealthStatus.needsAttention;
      case '2':
      case 'atRisk':
      case 'At Risk':
        return TreeHealthStatus.atRisk;
      case '3':
      case 'sick':
      case 'Sick':
        return TreeHealthStatus.sick;
      default:
        return TreeHealthStatus.healthy;
    }
  }

  void _handleBack(BuildContext context) {
    if (widget.source == 'rfid') {
      context.go('/scan');
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/my-trees');
    }
  }

  Future<
      ({
        String locationName,
        double latitude,
        double longitude,
      })?> _getDeviceLocation() async {
    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) return null;

    String locationName = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = <String>[
          if ((placemark.street ?? '').trim().isNotEmpty)
            placemark.street!.trim(),
          if ((placemark.subLocality ?? '').trim().isNotEmpty)
            placemark.subLocality!.trim(),
          if ((placemark.locality ?? '').trim().isNotEmpty)
            placemark.locality!.trim(),
          if ((placemark.subAdministrativeArea ?? '').trim().isNotEmpty)
            placemark.subAdministrativeArea!.trim(),
          if ((placemark.administrativeArea ?? '').trim().isNotEmpty)
            placemark.administrativeArea!.trim(),
          if ((placemark.country ?? '').trim().isNotEmpty)
            placemark.country!.trim(),
        ];

        final uniqueParts = <String>[];
        for (final part in parts) {
          if (part.isNotEmpty && !uniqueParts.contains(part)) {
            uniqueParts.add(part);
          }
        }
        locationName = uniqueParts.join(', ');
      }
    } catch (_) {
      locationName = '';
    }

    if (locationName.isEmpty) {
      locationName =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }

    return (
      locationName: locationName,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _backfillLocationIfMissing(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final isOnline = ref.read(connectivityStatusProvider).value ?? true;
    if (!isOnline) return;

    final location = (data['location'] ?? '').toString().trim();
    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);
    final alreadyHasLocation =
        location.isNotEmpty || (latitude != 0 && longitude != 0);

    if (_locationBackfillStarted || alreadyHasLocation) return;
    _locationBackfillStarted = true;

    final deviceLocation = await _getDeviceLocation();
    if (deviceLocation == null) return;

    await FirebaseFirestore.instance.collection('trees').doc(docId).set({
      'location': deviceLocation.locationName,
      'latitude': deviceLocation.latitude,
      'longitude': deviceLocation.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).user;
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    final treeAsync = ref.watch(treeByIdProvider(widget.treeId));

    return treeAsync.when(
      data: (tree) {
        if (tree == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tree Details'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBack(context),
              ),
            ),
            body: const Center(
              child: Text('Tree not found for this user'),
            ),
          );
        }

        final data = tree;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final docId = treeDocIdOf(data);
          if (docId.isNotEmpty) {
            _backfillLocationIfMissing(docId, data);
          }
        });

        final treeIdText = data['treeId']?.toString() ?? 'No ID';
        final location = data['location']?.toString() ?? '';
        final rfid = data['rfid']?.toString() ?? 'No RFID';
        final species = data['species']?.toString() ?? 'Unknown species';
        final ownerName =
            (data['ownerName']?.toString().trim().isNotEmpty ?? false)
                ? data['ownerName'].toString().trim()
                : (data['farmerName']?.toString().trim().isNotEmpty ?? false)
                    ? data['farmerName'].toString().trim()
                    : (currentUser?.name.trim().isNotEmpty ?? false)
                        ? currentUser!.name.trim()
                        : 'Unknown farmer';
        final latitude = _asNullableDouble(data['latitude']);
        final longitude = _asNullableDouble(data['longitude']);
        final latitudeText = latitude == null || latitude == 0
            ? '-'
            : latitude.toStringAsFixed(6);
        final longitudeText = longitude == null || longitude == 0
            ? '-'
            : longitude.toStringAsFixed(6);

        final age = (data['age'] is int)
            ? data['age']
            : int.tryParse(data['age']?.toString() ?? '0') ?? 0;

        final health = _statusLabel(data['healthStatus']);
        final lastInspection = _parseDate(data['lastinspectiondate']);
        final docId = treeDocIdOf(data);
        final syncAsync = ref.watch(treeSyncStatusProvider(docId));
        final isSynced = syncAsync.value ?? true;
        final treeModel = _buildTreeModel(data);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack(context);
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),

            body: CustomScrollView(
              slivers: [
                /// ✅ FIXED HEADER (NO OVERFLOW)
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _handleBack(context),
                  ),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("$age",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    const Text("YRS",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 8)),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  treeIdText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  species,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),

                          /// ✅ HEALTH
                          Positioned(
                            right: 16,
                            top: 62,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF66BB6A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check,
                                          size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(health,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSynced
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : Colors.orange.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isSynced
                                        ? 'Synced'
                                        : isOnline
                                            ? 'Sync pending'
                                            : 'Local only',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// TOP CARDS
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 250,
                                child: FutureBuilder<Map<String, dynamic>?>(
                                  future: _getTagDataFuture(
                                    data,
                                    isOnline: isOnline,
                                  ),
                                  builder: (context, tagSnapshot) {
                                    final tagData = tagSnapshot.data;
                                    final hasTagData = tagData != null;
                                    final tagTreeId = hasTagData
                                        ? (tagData['treeId'] ?? treeIdText)
                                            .toString()
                                        : '-';
                                    final tagHealth = hasTagData
                                        ? _tagHealthLabel(
                                            tagData['healthStatus'])
                                        : '-';
                                    final tagAge = hasTagData
                                        ? '${(tagData['treeAgeYears'] ?? 0)} yrs'
                                        : '-';
                                    final tagFarmer = hasTagData
                                        ? (tagData['farmerName'] ?? '-')
                                            .toString()
                                        : '-';
                                    final tagYield = hasTagData
                                        ? '${(tagData['lastYieldKg'] ?? 0)} kg'
                                        : '-';
                                    final tagLastScan = hasTagData
                                        ? _tagLastScanLabel(
                                            tagData['lastInspectionUnix'])
                                        : '-';

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TagDetailsScreen(
                                              treeId: treeIdText,
                                              tagData: tagData,
                                              healthLabelBuilder:
                                                  _tagHealthLabel,
                                              lastScanLabelBuilder:
                                                  _tagLastScanLabel,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _infoCard(
                                        color: const Color(0xFFF1F8E9),
                                        children: [
                                          const Text(
                                            "From The Tag",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text("Tree ID: $tagTreeId"),
                                          Text("Health: $tagHealth"),
                                          Text("Age: $tagAge"),
                                          Text("Farmer: $tagFarmer"),
                                          Text("Yield: $tagYield"),
                                          Text("Last Scan: $tagLastScan"),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 250,
                                child: _infoCard(
                                  color: const Color(0xFFE3F2FD),
                                  children: [
                                    const Text(
                                      "From the Cloud",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _menuItemButton(
                                      icon: Icons.history,
                                      title: "Full History",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TreeHistoryScreen(
                                                tree: treeModel),
                                          ),
                                        );
                                      },
                                    ),
                                    _menuItemButton(
                                      icon: Icons.photo,
                                      title: "Photos",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TreePhotosScreen(
                                              tree: treeModel,
                                              treeDocId: docId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _menuItemButton(
                                      icon: Icons.photo_library_outlined,
                                      title: "Issue Photos",
                                      onTap: () => _showIssueImageHistory(
                                        treeDocId: docId,
                                        treeId: treeIdText,
                                      ),
                                    ),
                                    _menuItemButton(
                                      icon: Icons.wb_sunny,
                                      title: "Weather",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TreeWeatherScreen(
                                                tree: treeModel),
                                          ),
                                        );
                                      },
                                    ),
                                    _menuItemButton(
                                      icon: Icons.show_chart,
                                      title: "Predictions",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TreePredictionsScreen(
                                              tree: treeModel,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        /// RFID
                        _infoCard(
                          color: const Color(0xFFFFF8E1),
                          border: Border.all(color: Colors.orange),
                          children: [
                            const Text("RFID Tag Status Panel"),
                            const SizedBox(height: 10),
                            Text("Tag ID: $rfid"),
                            const Text("Status: Active"),
                            const Text("Battery: 85%"),
                          ],
                        ),

                        _card("Tree Profile", [
                          _row("Species", species),
                          _row("Farmer", ownerName),
                        ]),

                        _card("Inspection & Care", [
                          _row("Last Inspection",
                              DateFormat('MMM d, yyyy').format(lastInspection)),
                          const Text(
                              "Notes: Main tree in the northern sector."),
                        ]),

                        _card("Growth Statistics", [
                          _row("Age", "$age yrs"),
                          _row("Health", health),
                        ]),

                        _card("Location", [
                          _row("Location", location.isEmpty ? '-' : location),
                          _row("Latitude", latitudeText),
                          _row("Longitude", longitudeText),
                          if (latitude != null && longitude != null) ...[
                            const SizedBox(height: 12),
                            _miniMap(latitude, longitude),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TreeMapScreen(
                                        lat: latitude,
                                        lng: longitude,
                                        title: '$treeIdText Location',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.open_in_full_rounded),
                                label: const Text('Open Full Map'),
                              ),
                            ),
                          ],
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
                    child: OutlinedButton.icon(
                      onPressed: docId.isEmpty
                          ? null
                          : () => _showReportIssue(
                                treeDocId: docId,
                                treeId: treeIdText,
                                species: species,
                                healthStatus: health,
                                ownerName: ownerName,
                              ),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text("Report Issue"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RFIDScanScreen(),
                          ),
                        );
                      },
                      child: const Text("Update"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
    );
  }

  /// COMPONENTS

  Widget _menuItemButton({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: onTap == null ? Colors.black87 : Colors.blue.shade700,
                  decoration: onTap == null
                      ? TextDecoration.none
                      : TextDecoration.underline,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoCard(
      {required List<Widget> children, Color? color, Border? border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Text("$label: $value");
  }

  Widget _miniMap(double lat, double lng) {
    final point = LatLng(lat, lng);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.kaushalyanxt_rfid',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    if (date is Map && date['_seconds'] != null) {
      final seconds = _asInt(date['_seconds']);
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.tryParse(date.toString()) ?? DateTime.now();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class TagDetailsScreen extends StatelessWidget {
  final String treeId;
  final Map<String, dynamic>? tagData;
  final String Function(dynamic rawStatus) healthLabelBuilder;
  final String Function(dynamic unixSeconds) lastScanLabelBuilder;

  const TagDetailsScreen({
    super.key,
    required this.treeId,
    required this.tagData,
    required this.healthLabelBuilder,
    required this.lastScanLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final hasTagData = tagData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Tag Details'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'From The Tag',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _tagRow(
                    'Tree ID',
                    hasTagData
                        ? (tagData!['treeId'] ?? treeId).toString()
                        : '-'),
                _tagRow(
                    'Health',
                    hasTagData
                        ? healthLabelBuilder(tagData!['healthStatus'])
                        : '-'),
                _tagRow('Age',
                    hasTagData ? '${tagData!['treeAgeYears'] ?? 0} yrs' : '-'),
                _tagRow(
                    'Farmer',
                    hasTagData
                        ? (tagData!['farmerName'] ?? '-').toString()
                        : '-'),
                _tagRow('Yield',
                    hasTagData ? '${tagData!['lastYieldKg'] ?? 0} kg' : '-'),
                _tagRow(
                    'Last Scan',
                    hasTagData
                        ? lastScanLabelBuilder(tagData!['lastInspectionUnix'])
                        : '-'),
                _tagRow('EPC',
                    hasTagData ? (tagData!['epc'] ?? '-').toString() : '-'),
                _tagRow('TID',
                    hasTagData ? (tagData!['tid'] ?? '-').toString() : '-'),
                if (!hasTagData) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No tag data stored locally for this tree.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../farm_manager_data.dart';

class FarmDetailScreen extends ConsumerStatefulWidget {
  const FarmDetailScreen({
    super.key,
    this.farm,
  });

  final FarmManagerFarm? farm;

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
  Future<FarmManagerLinkedFarmer?>? _linkedFarmerFuture;
  LatLng? _userLocation;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _syncLinkedFarmerFuture();
    _loadUserLocation();
  }

  @override
  void didUpdateWidget(covariant FarmDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farm?.id != widget.farm?.id) {
      _syncLinkedFarmerFuture();
    }
  }

  void _syncLinkedFarmerFuture() {
    final farm = widget.farm;
    _linkedFarmerFuture =
        farm == null ? Future.value(null) : loadLinkedFarmerForFarm(farm);
  }

  Future<void> _loadUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _launchExternalUri(
    Uri uri, {
    required String failureMessage,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _openPhone(String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) return;
    await _launchExternalUri(
      Uri(
        scheme: 'tel',
        path: trimmedPhone,
      ),
      failureMessage: 'Unable to open the dialer for this farmer.',
    );
  }

  Future<void> _openEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) return;
    await _launchExternalUri(
      Uri(
        scheme: 'mailto',
        path: trimmedEmail,
      ),
      failureMessage: 'Unable to open email for this farmer.',
    );
  }

  Future<void> _openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final query = Uri.encodeComponent('$latitude,$longitude');
    await _launchExternalUri(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      failureMessage: 'Unable to open directions for this location.',
    );
  }

  void _openFarmerManagementScreen({
    required FarmManagerFarm farm,
    FarmManagerLinkedFarmer? linkedFarmer,
  }) {
    final farmerId = (linkedFarmer?.id.trim().isNotEmpty ?? false)
        ? linkedFarmer!.id.trim()
        : farm.farmerId.trim();

    context.push(
      '${RoutePaths.farmManagerFarmers}?farmerId='
      '${Uri.encodeComponent(farmerId)}&farmId='
      '${Uri.encodeComponent(farm.id)}&farmLabel='
      '${Uri.encodeComponent(farm.name)}',
    );
  }

  String _formatDateLabel(dynamic value) {
    final parsed = parseDateTime(value);
    if (parsed == null) {
      return 'Not available';
    }
    return _dateFormatter.format(parsed.toLocal());
  }

  String _roleLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Farmer';
    }
    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  int _treePriority(Map<String, dynamic> tree) {
    switch (healthLabel(tree['healthStatus'])) {
      case 'Critical':
        return 0;
      case 'At Risk':
        return 1;
      case 'Needs Attention':
        return 2;
      case 'Healthy':
        return 3;
      default:
        return 4;
    }
  }

  List<Map<String, dynamic>> _sortedTrees(List<Map<String, dynamic>> trees) {
    final sortedTrees = List<Map<String, dynamic>>.from(trees);
    sortedTrees.sort((left, right) {
      final priorityCompare =
          _treePriority(left).compareTo(_treePriority(right));
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final leftTreeId =
          firstNonEmptyString([left['treeId']], fallback: 'tree').toLowerCase();
      final rightTreeId = firstNonEmptyString(
        [right['treeId']],
        fallback: 'tree',
      ).toLowerCase();
      return leftTreeId.compareTo(rightTreeId);
    });
    return sortedTrees;
  }

  void _showTreeDetailSheet(
    Map<String, dynamic> tree,
    List<FarmManagerIssue> farmIssues,
  ) {
    final treeId = firstNonEmptyString([tree['treeId']], fallback: 'Tree');
    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    final species = firstNonEmptyString(
      [tree['species']],
      fallback: 'Not set',
    );
    final farmerName = firstNonEmptyString(
      [
        tree['ownerName'],
        tree['farmerName'],
        tree['userName'],
      ],
      fallback: 'Farmer',
    );
    final location = firstNonEmptyString(
      [
        tree['location'],
        tree['plotNumber'],
        tree['plot'],
      ],
      fallback: 'Location unavailable',
    );
    final health = healthLabel(tree['healthStatus']);
    final latitude = asNullableDouble(tree['latitude']);
    final longitude = asNullableDouble(tree['longitude']);
    final treeAge = asInt(tree['treeAge'] ?? tree['age']);
    final lastYield = asDouble(tree['lastYieldKg']);
    final harvestMonth = firstNonEmptyString(
      [tree['harvestMonth']],
      fallback: 'Not set',
    );
    final isScanned = tree['isScanned'] == true;
    final relatedIssues = treeDocId.isEmpty
        ? const <FarmManagerIssue>[]
        : farmIssues
            .where((issue) => issue.treeDocId == treeDocId)
            .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              treeId,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              farmerName,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: healthColor(health).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          health,
                          style: TextStyle(
                            color: healthColor(health),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _TreeSummaryPill(
                        icon: Icons.park_outlined,
                        label: species,
                        color: Colors.green.shade700,
                      ),
                      _TreeSummaryPill(
                        icon: Icons.qr_code_2_outlined,
                        label: isScanned ? 'Scanned' : 'Not scanned',
                        color: isScanned
                            ? Colors.teal.shade700
                            : Colors.orange.shade700,
                      ),
                      _TreeSummaryPill(
                        icon: Icons.warning_amber_rounded,
                        label: relatedIssues.isEmpty
                            ? 'No issues'
                            : '${relatedIssues.length} issues',
                        color: relatedIssues.isEmpty
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView(
                      children: [
                        _DetailRow(label: 'Location', value: location),
                        _DetailRow(
                          label: 'Last Inspection',
                          value: _formatDateLabel(
                            tree['lastinspectiondate'] ??
                                tree['lastInspectionDate'] ??
                                tree['updatedAt'],
                          ),
                        ),
                        _DetailRow(
                          label: 'Tree Age',
                          value: treeAge <= 0 ? 'Not set' : '$treeAge years',
                        ),
                        _DetailRow(
                          label: 'Last Yield',
                          value: lastYield <= 0
                              ? 'Not set'
                              : '${lastYield.toStringAsFixed(1)} kg',
                        ),
                        _DetailRow(label: 'Harvest Month', value: harvestMonth),
                        _DetailRow(
                          label: 'Coordinates',
                          value: latitude == null || longitude == null
                              ? 'Not available'
                              : '${latitude.toStringAsFixed(6)}, '
                                  '${longitude.toStringAsFixed(6)}',
                        ),
                        if (relatedIssues.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Linked Issues',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...relatedIssues.take(4).map(
                                (issue) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        issue.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        issue.note.isEmpty
                                            ? issueStatusLabel(issue.status)
                                            : issue.note,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(treeId, 'Tree ID'),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy Tree ID'),
                        ),
                      ),
                      if (latitude != null && longitude != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openDirections(
                              latitude: latitude,
                              longitude: longitude,
                            ),
                            icon: const Icon(Icons.route_outlined),
                            label: const Text('Directions'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTreeInventorySheet(
    FarmManagerFarm farm,
    List<FarmManagerIssue> farmIssues,
  ) {
    final sortedTrees = _sortedTrees(farm.trees);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${farm.name} Trees',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sortedTrees.length} trees linked to ${farm.farmerName}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: sortedTrees.isEmpty
                        ? Center(
                            child: Text(
                              'No tree records were linked to this farm yet.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          )
                        : ListView.separated(
                            itemCount: sortedTrees.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tree = sortedTrees[index];
                              final treeId = firstNonEmptyString(
                                [tree['treeId']],
                                fallback: 'Tree',
                              );
                              final health = healthLabel(tree['healthStatus']);
                              final treeDocId =
                                  (tree['_docId'] ?? '').toString().trim();
                              final issueCount = treeDocId.isEmpty
                                  ? 0
                                  : farmIssues
                                      .where(
                                        (issue) => issue.treeDocId == treeDocId,
                                      )
                                      .length;

                              return _TreePreviewTile(
                                treeId: treeId,
                                subtitle: firstNonEmptyString(
                                  [
                                    tree['species'],
                                    tree['location'],
                                  ],
                                  fallback: 'Details unavailable',
                                ),
                                health: health,
                                issueCount: issueCount,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    _showTreeDetailSheet(tree, farmIssues);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkedFarmerSection(FarmManagerFarm farm) {
    return FutureBuilder<FarmManagerLinkedFarmer?>(
      future: _linkedFarmerFuture,
      builder: (context, snapshot) {
        final linkedFarmer = snapshot.data;
        final farmerName = (linkedFarmer?.name.trim().isNotEmpty ?? false)
            ? linkedFarmer!.name.trim()
            : farm.farmerName;
        final farmerPhone = (linkedFarmer?.phone.trim().isNotEmpty ?? false)
            ? linkedFarmer!.phone.trim()
            : farm.farmerPhone;
        final farmerEmail = (linkedFarmer?.email.trim().isNotEmpty ?? false)
            ? linkedFarmer!.email.trim()
            : farm.farmerEmail;
        final hasContact =
            farmerPhone.trim().isNotEmpty || farmerEmail.trim().isNotEmpty;
        final roleLabel = (linkedFarmer?.role.trim().isNotEmpty ?? false)
            ? linkedFarmer!.role.trim().replaceAll('_', ' ')
            : 'farmer';
        final managerCode =
            (linkedFarmer?.farmManagerCode.trim().isNotEmpty ?? false)
                ? linkedFarmer!.farmManagerCode.trim()
                : firstNonEmptyString(
                    farm.trees.map((tree) => tree['farmManagerCode']).toList(),
                  );
        final managerName =
            (linkedFarmer?.farmManagerName.trim().isNotEmpty ?? false)
                ? linkedFarmer!.farmManagerName.trim()
                : '';
        final farmerId = (linkedFarmer?.id.trim().isNotEmpty ?? false)
            ? linkedFarmer!.id.trim()
            : farm.farmerId;

        return InkWell(
          onTap: () => _openFarmerManagementScreen(
            farm: farm,
            linkedFarmer: linkedFarmer,
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        initialsFor(farmerName),
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            farmerPhone.isNotEmpty
                                ? farmerPhone
                                : farmerEmail.isNotEmpty
                                    ? farmerEmail
                                    : 'No contact details available',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TreeSummaryPill(
                                icon: Icons.person_outline,
                                label: _roleLabel(roleLabel),
                                color: Colors.green.shade700,
                              ),
                              if (managerCode.isNotEmpty)
                                _TreeSummaryPill(
                                  icon: Icons.link_outlined,
                                  label: 'Code $managerCode',
                                  color: Colors.teal.shade700,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Farmer ID',
                  value: farmerId.isEmpty ? 'Not available' : farmerId,
                ),
                _DetailRow(
                  label: 'Phone',
                  value: farmerPhone.isEmpty ? 'Not available' : farmerPhone,
                ),
                _DetailRow(
                  label: 'Email',
                  value: farmerEmail.isEmpty ? 'Not available' : farmerEmail,
                ),
                _DetailRow(
                  label: 'Linked To',
                  value: managerName.isEmpty && managerCode.isEmpty
                      ? 'Manager link not available'
                      : managerName.isEmpty
                          ? managerCode
                          : managerCode.isEmpty
                              ? managerName
                              : '$managerName ($managerCode)',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionChipButton(
                      icon: Icons.call_outlined,
                      label: 'Call',
                      onTap: farmerPhone.isEmpty
                          ? null
                          : () => _openPhone(farmerPhone),
                    ),
                    _ActionChipButton(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      onTap: farmerEmail.isEmpty
                          ? null
                          : () => _openEmail(farmerEmail),
                    ),
                    _ActionChipButton(
                      icon: Icons.copy_outlined,
                      label: 'Copy',
                      onTap: hasContact
                          ? () => _copyToClipboard(
                                farmerPhone.isNotEmpty
                                    ? farmerPhone
                                    : farmerEmail,
                                'Farmer contact',
                              )
                          : null,
                    ),
                    _ActionChipButton(
                      icon: Icons.groups_outlined,
                      label: 'Manage',
                      onTap: () => _openFarmerManagementScreen(
                        farm: farm,
                        linkedFarmer: linkedFarmer,
                      ),
                    ),
                  ],
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Linked farmer profile could not be loaded, so this view is using farm and tree records.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    final farm = widget.farm;
    if (farm == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Farm Details'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Open a farm from the directory to view its details.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final treeMarkers = farm.trees
        .map((tree) {
          final latitude = asNullableDouble(tree['latitude']);
          final longitude = asNullableDouble(tree['longitude']);
          if (latitude == null || longitude == null) return null;
          return (
            point: LatLng(latitude, longitude),
            title: firstNonEmptyString([tree['treeId']], fallback: 'Tree'),
            health: healthLabel(tree['healthStatus']),
          );
        })
        .whereType<({LatLng point, String title, String health})>()
        .toList(growable: false);

    final center = farm.hasCoordinates
        ? LatLng(farm.latitude!, farm.longitude!)
        : treeMarkers.isNotEmpty
            ? treeMarkers.first.point
            : _userLocation ?? const LatLng(12.9716, 77.5946);

    final treeIds = farm.treeDocIds.toSet();
    final sortedTrees = _sortedTrees(farm.trees);
    final healthyTreeCount = farm.trees
        .where((tree) => healthLabel(tree['healthStatus']) == 'Healthy')
        .length;
    final monitoringTreeCount = farm.trees
        .where(
          (tree) => healthLabel(tree['healthStatus']) == 'Needs Attention',
        )
        .length;
    final criticalTreeCount = farm.trees
        .where(
          (tree) => {
            'At Risk',
            'Critical',
          }.contains(healthLabel(tree['healthStatus'])),
        )
        .length;
    final mapLatitude = farm.hasCoordinates
        ? farm.latitude
        : treeMarkers.isNotEmpty
            ? treeMarkers.first.point.latitude
            : null;
    final mapLongitude = farm.hasCoordinates
        ? farm.longitude
        : treeMarkers.isNotEmpty
            ? treeMarkers.first.point.longitude
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collectionGroup('issues').snapshots(),
        builder: (context, snapshot) {
          final issueDocs = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final issues = buildIssueSummaries(
            issueDocs: issueDocs,
            scopedTrees: farm.trees,
            scope: const FarmManagerScope(
              managerUid: '',
              managerEmail: '',
              managerCode: '',
              linkedFarmerIds: <String>{},
              linkedFarmerEmails: <String>{},
            ),
          ).where((issue) => treeIds.contains(issue.treeDocId)).toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        farm.location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade900,
                          Colors.green.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _HeroChip(
                                icon: Icons.park_outlined,
                                label: '${farm.totalTrees} trees',
                              ),
                              _HeroChip(
                                icon: Icons.favorite_outline,
                                label: '${farm.healthPercent}% healthy',
                              ),
                              _HeroChip(
                                icon: Icons.warning_amber_rounded,
                                label: issues.isEmpty
                                    ? 'No issues'
                                    : '${issues.length} issues',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Alerts',
                              value: '${farm.alertCount}',
                              icon: Icons.warning_amber_rounded,
                              color: farm.alertCount == 0
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'Scanned',
                              value: '${farm.scannedTrees}/${farm.totalTrees}',
                              icon: Icons.sync_outlined,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Linked Farmer Details',
                        actionLabel: 'Open',
                        onActionTap: () => _openFarmerManagementScreen(
                          farm: farm,
                        ),
                        child: _buildLinkedFarmerSection(farm),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Farm Map',
                        actionLabel: issues.isEmpty ? null : 'Issue tracker',
                        onActionTap: issues.isEmpty
                            ? null
                            : () {
                                context.push(
                                  '${RoutePaths.farmManagerIssues}?farmId='
                                  '${Uri.encodeComponent(farm.id)}&farmLabel='
                                  '${Uri.encodeComponent(farm.name)}',
                                );
                              },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 230,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      options: MapOptions(
                                        initialCenter: center,
                                        initialZoom: 15,
                                      ),
                                      children: [
                                        if (isOnline)
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.example.kaushalyanxt_rfid',
                                          ),
                                        MarkerLayer(
                                          markers: [
                                            if (farm.hasCoordinates)
                                              Marker(
                                                point: LatLng(
                                                  farm.latitude!,
                                                  farm.longitude!,
                                                ),
                                                width: 40,
                                                height: 40,
                                                child: const Icon(
                                                  Icons.agriculture_rounded,
                                                  color: Colors.green,
                                                  size: 32,
                                                ),
                                              ),
                                            ...treeMarkers.map(
                                              (tree) => Marker(
                                                point: tree.point,
                                                width: 34,
                                                height: 34,
                                                child: Icon(
                                                  Icons.park,
                                                  color:
                                                      healthColor(tree.health),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            if (_userLocation != null)
                                              Marker(
                                                point: _userLocation!,
                                                width: 34,
                                                height: 34,
                                                child: const Icon(
                                                  Icons.location_pin,
                                                  color: Colors.red,
                                                  size: 28,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (!isOnline)
                                      Container(
                                        color: const Color(0xCCFFFFFF),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.all(16),
                                        child: const Text(
                                          'Map tiles are unavailable while the device is offline.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _loadingLocation
                                  ? 'Getting your location...'
                                  : _userLocation == null
                                      ? 'Showing farm and tree markers.'
                                      : 'Showing farm, tree, and current location markers.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            if (mapLatitude != null &&
                                mapLongitude != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openDirections(
                                    latitude: mapLatitude,
                                    longitude: mapLongitude,
                                  ),
                                  icon: const Icon(Icons.route_outlined),
                                  label: const Text('Open Directions'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Linked Farmer Tree Details',
                        actionLabel: sortedTrees.isEmpty ? null : 'View all',
                        onActionTap: sortedTrees.isEmpty
                            ? null
                            : () => _showTreeInventorySheet(farm, issues),
                        child: sortedTrees.isEmpty
                            ? Text(
                                'No tree records were linked to this farm yet.',
                                style: TextStyle(color: Colors.grey.shade700),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _TreeSummaryPill(
                                        icon: Icons.favorite_outline,
                                        label: '$healthyTreeCount healthy',
                                        color: Colors.green.shade700,
                                      ),
                                      _TreeSummaryPill(
                                        icon: Icons.timelapse_outlined,
                                        label:
                                            '$monitoringTreeCount monitoring',
                                        color: Colors.orange.shade700,
                                      ),
                                      _TreeSummaryPill(
                                        icon: Icons.warning_amber_rounded,
                                        label: '$criticalTreeCount critical',
                                        color: Colors.red.shade700,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...sortedTrees.take(3).map((tree) {
                                    final treeId = firstNonEmptyString(
                                      [tree['treeId']],
                                      fallback: 'Tree',
                                    );
                                    final treeDocId = (tree['_docId'] ?? '')
                                        .toString()
                                        .trim();
                                    final issueCount = treeDocId.isEmpty
                                        ? 0
                                        : issues
                                            .where(
                                              (issue) =>
                                                  issue.treeDocId == treeDocId,
                                            )
                                            .length;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _TreePreviewTile(
                                        treeId: treeId,
                                        subtitle: firstNonEmptyString(
                                          [
                                            tree['species'],
                                            tree['location'],
                                          ],
                                          fallback: 'Details unavailable',
                                        ),
                                        health: healthLabel(
                                          tree['healthStatus'],
                                        ),
                                        issueCount: issueCount,
                                        onTap: () =>
                                            _showTreeDetailSheet(tree, issues),
                                      ),
                                    );
                                  }),
                                  if (sortedTrees.length > 3)
                                    Text(
                                      'Showing 3 of ${sortedTrees.length} trees. Tap View all to open the full list.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                      ),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (actionLabel != null && onActionTap != null)
                TextButton(
                  onPressed: onActionTap,
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final borderColor = enabled ? Colors.green.shade200 : Colors.grey.shade300;
    final textColor = enabled ? Colors.green.shade800 : Colors.grey.shade500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeSummaryPill extends StatelessWidget {
  const _TreeSummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreePreviewTile extends StatelessWidget {
  const _TreePreviewTile({
    required this.treeId,
    required this.subtitle,
    required this.health,
    required this.issueCount,
    required this.onTap,
  });

  final String treeId;
  final String subtitle;
  final String health;
  final int issueCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = healthColor(health);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.park_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    treeId,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  health,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  issueCount == 0 ? 'No issues' : '$issueCount issues',
                  style: TextStyle(
                    color: issueCount == 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

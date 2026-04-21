import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/router/route_paths.dart';
import '../farm_manager_data.dart';

class FarmDetailScreen extends StatefulWidget {
  const FarmDetailScreen({
    super.key,
    this.farm,
  });

  final FarmManagerFarm? farm;

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  LatLng? _userLocation;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
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

  @override
  Widget build(BuildContext context) {
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
                        title: 'Assigned Farmer',
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                initialsFor(farm.farmerName),
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
                                    farm.farmerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    farm.farmerPhone.isNotEmpty
                                        ? farm.farmerPhone
                                        : farm.farmerEmail.isNotEmpty
                                            ? farm.farmerEmail
                                            : 'No contact details available',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: farm.farmerPhone.isEmpty &&
                                      farm.farmerEmail.isEmpty
                                  ? null
                                  : () async {
                                      final text = farm.farmerPhone.isNotEmpty
                                          ? farm.farmerPhone
                                          : farm.farmerEmail;
                                      await Clipboard.setData(
                                        ClipboardData(text: text),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Contact copied to clipboard'),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Farm Map',
                        actionLabel: issues.isEmpty ? null : 'Issue tracker',
                        onActionTap: issues.isEmpty
                            ? null
                            : () {
                                context.push(
                                  '${RoutePaths.farmManagerIssues}?farm='
                                  '${Uri.encodeComponent(farm.id)}',
                                );
                              },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 230,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: center,
                                    initialZoom: 15,
                                  ),
                                  children: [
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
                                              color: healthColor(tree.health),
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

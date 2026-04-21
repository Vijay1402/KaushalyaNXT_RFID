import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmManagerDetails extends StatefulWidget {
  final String? farmId;

  const FarmManagerDetails({super.key, this.farmId});

  @override
  State<FarmManagerDetails> createState() => _FarmManagerDetailsState();
}

class _FarmManagerDetailsState extends State<FarmManagerDetails> {
  late LatLng userLocation;
  bool isLoadingLocation = true;
  bool isLoadingFarm = true;

  // Farm data
  Map<String, dynamic> farmData = {};
  String farmName = 'Farm';
  String location = 'Location';
  int totalTrees = 0;
  int area = 0;
  String farmerName = 'Farmer';
  String farmerPhone = '';
  String farmerEmail = '';
  LatLng? farmCenter;

  // Trees, Activities, Performance data
  List<Map<String, dynamic>> treesList = [];
  List<Map<String, dynamic>> activitiesList = [];
  Map<String, dynamic> performanceData = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchFarmData();
    _fetchTreesData();
    _fetchActivitiesData();
    _fetchPerformanceData();
  }

  Future<void> _fetchFarmData() async {
    try {
      Map<String, dynamic>? loadedFarm;
      String? loadedFarmId;

      if (widget.farmId == null || widget.farmId!.isEmpty) {
        // If no farmId provided, use default or first farm
        final snapshot =
            await FirebaseFirestore.instance.collection('farms').limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          loadedFarm = snapshot.docs.first.data();
          loadedFarmId = snapshot.docs.first.id;
        }
      } else {
        // Fetch specific farm by ID
        final doc = await FirebaseFirestore.instance
            .collection('farms')
            .doc(widget.farmId)
            .get();

        if (doc.exists) {
          loadedFarm = doc.data() ?? {};
          loadedFarmId = doc.id;
        }
      }

      if (loadedFarm != null) {
        farmData = {
          ...loadedFarm,
          'id': loadedFarmId ?? loadedFarm['id'],
        };
        _updateFarmUI();
        await _fetchAssignedUserDetails();
        await Future.wait([
          _fetchTreesData(),
          _fetchActivitiesData(),
          _fetchPerformanceData(),
        ]);
      }
    } catch (e) {
      print('Error fetching farm data: $e');
    }

    if (mounted) {
      setState(() {
        isLoadingFarm = false;
      });
    }
  }

  void _updateFarmUI() {
    setState(() {
      farmName = farmData['name'] ?? 'Farm';
      location = farmData['location'] ?? 'Location';
      totalTrees = farmData['treesCount'] ?? 0;
      area = farmData['area'] ?? 0;
      farmerName = _firstNonEmptyString([
        farmData['farmerName'],
        farmData['ownerName'],
        farmData['assignedUserName'],
        farmData['userName'],
      ], fallback: 'Farmer');
      farmerPhone = _firstNonEmptyString([
        farmData['farmerPhone'],
        farmData['phone'],
        farmData['mobile'],
      ]);
      farmerEmail = _firstNonEmptyString([
        farmData['farmerEmail'],
        farmData['email'],
      ]);

      // Parse location if available
      if (farmData['latitude'] != null && farmData['longitude'] != null) {
        farmCenter = LatLng(
          (farmData['latitude'] as num).toDouble(),
          (farmData['longitude'] as num).toDouble(),
        );
      }
    });
  }

  Future<void> _fetchAssignedUserDetails() async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final userId = _firstNonEmptyString([
        farmData['farmerId'],
        farmData['userId'],
        farmData['uid'],
        farmData['assignedUserId'],
        farmData['ownerId'],
      ]);

      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      if (userId.isNotEmpty) {
        final byId = await users.doc(userId).get();
        if (byId.exists) {
          userDoc = byId;
        }
      }

      if (userDoc == null) {
        final email = _firstNonEmptyString([
          farmData['farmerEmail'],
          farmData['email'],
          farmData['userEmail'],
        ]);
        if (email.isNotEmpty) {
          final query = await users.where('email', isEqualTo: email).limit(1).get();
          if (query.docs.isNotEmpty) {
            userDoc = query.docs.first;
          }
        }
      }

      if (userDoc == null) {
        final name = _firstNonEmptyString([
          farmData['farmerName'],
          farmData['ownerName'],
          farmData['assignedUserName'],
        ]);
        if (name.isNotEmpty) {
          final query = await users.where('name', isEqualTo: name).limit(1).get();
          if (query.docs.isNotEmpty) {
            userDoc = query.docs.first;
          }
        }
      }

      if (!mounted || userDoc == null || !userDoc.exists) {
        return;
      }

      final userData = userDoc.data() ?? <String, dynamic>{};
      setState(() {
        farmerName = _firstNonEmptyString([
          userData['name'],
          farmerName,
        ], fallback: 'Farmer');
        farmerPhone = _firstNonEmptyString([
          userData['phone'],
          userData['mobile'],
          farmerPhone,
        ]);
        farmerEmail = _firstNonEmptyString([
          userData['email'],
          farmerEmail,
        ]);
      });
    } catch (e) {
      print('Error fetching assigned user details: $e');
    }
  }

  String _firstNonEmptyString(
    List<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  Uri? _buildPhoneUri(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty) return null;
    return Uri(scheme: 'tel', path: normalized);
  }

  Future<void> _fetchTreesData() async {
    try {
      final farmId = widget.farmId ?? farmData['id'];
      if (farmId == null || farmId.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('farms')
          .doc(farmId)
          .collection('trees')
          .get();

      if (mounted) {
        setState(() {
          treesList = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      print('Error fetching trees data: $e');
    }
  }

  Future<void> _fetchActivitiesData() async {
    try {
      final farmId = widget.farmId ?? farmData['id'];
      if (farmId == null || farmId.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('farms')
          .doc(farmId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          activitiesList = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      print('Error fetching activities data: $e');
    }
  }

  Future<void> _fetchPerformanceData() async {
    try {
      final farmId = widget.farmId ?? farmData['id'];
      if (farmId == null || farmId.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('farms')
          .doc(farmId)
          .collection('performance')
          .doc('monthly')
          .get();

      if (doc.exists && mounted) {
        setState(() {
          performanceData = doc.data() ?? {};
        });
      }
    } catch (e) {
      print('Error fetching performance data: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // Use default location if permission denied
        userLocation = const LatLng(13.0827, 77.5877);
      } else {
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        userLocation = LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      print('Location error: $e');
      // Fallback to default location
      userLocation = const LatLng(13.0827, 77.5877);
    }

    if (mounted) {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFarmHeader(),
            _buildOverviewSection(),
            _buildContactCard(),
            _buildFarmMap(), // ✅ REAL MAP WITH USER LOCATION
            _buildTreesSection(),
            _buildRecentActivities(),
            _buildPerformanceSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------
  Widget _buildFarmHeader() {
    return Container(
      color: const Color(0xFF2D7A3E),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            farmName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            location,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.circle, color: Colors.green, size: 12),
              SizedBox(width: 8),
              Text('Farm active', style: TextStyle(color: Colors.white)),
              SizedBox(width: 16),
              Text('Last updated 10 min ago',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- OVERVIEW ----------------
  Widget _buildOverviewSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _card('🌲', '$totalTrees', 'Total Trees'),
          _card('📍', '$area ac', 'Area'),
        ],
      ),
    );
  }

  Widget _card(String icon, String title, String sub) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ---------------- CONTACT ----------------
  Widget _buildContactCard() {
    // Extract initials safely (up to 2 characters)
    final parts = farmerName.split(' ');
    String initials = '';
    for (var part in parts) {
      if (part.isNotEmpty && initials.length < 2) {
        initials += part[0].toUpperCase();
      }
    }
    initials = initials.padRight(2, 'R'); // Fallback to 'K' if needed

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ASSIGNED FARMER',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2D7A3E),
                child:
                    Text(initials, style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (farmerPhone.isNotEmpty)
                      Text(
                        farmerPhone,
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    else if (farmerEmail.isNotEmpty)
                      Text(
                        farmerEmail,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () async {
                  final uri = _buildPhoneUri(farmerPhone);

                  if (uri == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No phone number found for this user'),
                      ),
                    );
                    return;
                  }

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open dialer')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- MAP (MAIN PART) ----------------
  Widget _buildFarmMap() {
    if (isLoadingLocation) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FARM MAP',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    final List<Marker> markers = [
      // User's current location (red pin)
      Marker(
        point: userLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 35),
      ),

      // Example tree markers around user location
      Marker(
        point: LatLng(
            userLocation.latitude + 0.0003, userLocation.longitude + 0.0003),
        child: const Icon(Icons.park, color: Colors.green, size: 30),
      ),
      Marker(
        point: LatLng(
            userLocation.latitude - 0.0003, userLocation.longitude - 0.0003),
        child: const Icon(Icons.park, color: Colors.green, size: 30),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FARM MAP',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: userLocation,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'kaushalyanxt_rfid',
                  ),

                  MarkerLayer(markers: markers),

                  // Farm boundary (polygon) around user location
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: [
                          LatLng(userLocation.latitude + 0.0005,
                              userLocation.longitude + 0.0005),
                          LatLng(userLocation.latitude + 0.0005,
                              userLocation.longitude - 0.0005),
                          LatLng(userLocation.latitude - 0.0005,
                              userLocation.longitude - 0.0005),
                          LatLng(userLocation.latitude - 0.0005,
                              userLocation.longitude + 0.0005),
                        ],
                        color: Colors.green.withOpacity(0.2),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TREES ----------------
  Widget _buildTreesSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TREES',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[600])),
              Text('View All',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 12),
          if (treesList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No trees data available',
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            Column(
              children: treesList.asMap().entries.map((entry) {
                final tree = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key < treesList.length - 1 ? 12 : 0),
                  child: _treeItem(
                    '🌳',
                    tree['name'] ?? 'Unknown Tree',
                    '${tree['count'] ?? 0} trees',
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              _statusTag('Healthy'),
              _statusTag('Moderate'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _treeItem(String icon, String name, String count) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(count,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _statusTag(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  // ---------------- ACTIVITIES ----------------
  Widget _buildRecentActivities() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT ACTIVITIES',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[600])),
              Text('View All',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 12),
          if (activitiesList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No activities available',
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            Column(
              children: activitiesList.asMap().entries.map((entry) {
                final activity = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key < activitiesList.length - 1 ? 12 : 0),
                  child: _activityItem(
                    icon: _getActivityIcon(activity['type'] ?? ''),
                    title: activity['title'] ?? 'Activity',
                    subtitle: activity['subtitle'] ?? '',
                    status: activity['status'] ?? 'Pending',
                    statusColor: _getStatusColor(activity['status'] ?? ''),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'watering':
        return Icons.water_drop;
      case 'fertilizer':
        return Icons.grain;
      case 'pest_inspection':
        return Icons.bug_report;
      default:
        return Icons.check_circle;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'scheduled':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _activityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: statusColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              )),
        ),
      ],
    );
  }

  // ---------------- PERFORMANCE ----------------
  Widget _buildPerformanceSection() {
    final monthlyData = performanceData['months'] ?? [];
    final growthPercentage = performanceData['growth_percentage'] ?? '+12%';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERFORMANCE',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Yield/Growth',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$growthPercentage this season',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: monthlyData.isEmpty
                        ? <Widget>[
                            _chartBar(20),
                            _chartBar(35),
                            _chartBar(50),
                            _chartBar(65),
                            _chartBar(80),
                            _chartBar(75),
                          ]
                        : (monthlyData as List)
                            .map(
                                (value) => _chartBar((value as num).toDouble()))
                            .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: (performanceData['month_labels'] as List?)
                          ?.map((month) => Text(month,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600])))
                          .toList() ??
                      [
                        Text('Nov',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                        Text('Dec',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                        Text('Jan',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                        Text('Feb',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                        Text('Mar',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                        Text('Apr',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                      ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBar(double height) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2D7A3E),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

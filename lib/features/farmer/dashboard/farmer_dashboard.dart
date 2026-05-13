import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../app/router/route_paths.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../tree_details/tree_controller.dart';

final _pendingTreeSyncCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authServiceProvider).getCurrentUser();
  if (user == null) return 0;
  final items = await LocalCacheService().getPendingTreeSyncs(user.uid);
  return items.length;
});

final _dashboardWeatherProvider =
    FutureProvider.autoDispose<_DashboardWeather>((ref) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw StateError('Turn on location services to show local weather.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError('Allow location permission to show local weather.');
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 12),
    ),
  );
  final locationName = await _locationNameFor(
    position.latitude,
    position.longitude,
  );
  final weather = await _fetchCurrentWeather(
    position.latitude,
    position.longitude,
  );

  return weather.copyWith(locationName: locationName);
});

class _DashboardWeather {
  const _DashboardWeather({
    required this.locationName,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.rain,
    required this.cloudCover,
    required this.weatherCode,
  });

  final String locationName;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double rain;
  final double cloudCover;
  final int weatherCode;

  String get condition => _weatherCondition(weatherCode);
  String get advice => _weatherAdvice(weatherCode, rain);

  _DashboardWeather copyWith({String? locationName}) {
    return _DashboardWeather(
      locationName: locationName ?? this.locationName,
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      rain: rain,
      cloudCover: cloudCover,
      weatherCode: weatherCode,
    );
  }
}

Future<String> _locationNameFor(double latitude, double longitude) async {
  try {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) return 'Current location';

    final place = placemarks.first;
    final parts = [
      place.locality,
      place.subLocality,
      place.administrativeArea,
      place.country,
    ]
        .map((part) => (part ?? '').trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return parts.isEmpty ? 'Current location' : parts.join(', ');
  } catch (_) {
    return 'Current location';
  }
}

Future<_DashboardWeather> _fetchCurrentWeather(
  double latitude,
  double longitude,
) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': latitude.toStringAsFixed(5),
    'longitude': longitude.toStringAsFixed(5),
    'current':
        'temperature_2m,relative_humidity_2m,precipitation,rain,weather_code,cloud_cover,wind_speed_10m',
    'timezone': 'auto',
  });

  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Unable to load weather right now.');
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>? ?? {};

    return _DashboardWeather(
      locationName: 'Current location',
      temperature: _asDouble(current['temperature_2m']),
      humidity: _asDouble(current['relative_humidity_2m']),
      windSpeed: _asDouble(current['wind_speed_10m']),
      rain: _asDouble(current['rain'] ?? current['precipitation']),
      cloudCover: _asDouble(current['cloud_cover']),
      weatherCode: _asDouble(current['weather_code']).round(),
    );
  } finally {
    client.close(force: true);
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

String _weatherCondition(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 67) return 'Rain expected';
  if (code <= 77) return 'Cool and cloudy';
  if (code <= 82) return 'Showers nearby';
  if (code <= 99) return 'Thunderstorm risk';
  return 'Weather today';
}

String _weatherAdvice(int code, double rain) {
  if (code >= 95) return 'Thunderstorm risk - avoid field work if possible.';
  if (rain > 2 || (code >= 61 && code <= 82)) {
    return 'Rain is likely - reduce irrigation and protect equipment.';
  }
  if (code == 0 || code <= 3) {
    return 'Good conditions for field work today.';
  }
  return 'Check crops and plan irrigation based on field moisture.';
}

class FarmerDashboard extends ConsumerWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final treesAsync = ref.watch(treesProvider);
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    final pendingSyncAsync = ref.watch(_pendingTreeSyncCountProvider);
    final weatherAsync = ref.watch(_dashboardWeatherProvider);
    final isCompact = ResponsiveLayout.isCompact(context);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);
    final userName =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Farmer';
    final stats = treesAsync.when(
      data: (trees) {
        final uniqueTrees = _dedupeTrees(trees);
        final total = uniqueTrees.length;
        final healthy = uniqueTrees.where((tree) {
          return _statusLabel(tree['healthStatus']) == 'Healthy';
        }).length;
        final needAttention = uniqueTrees.where((tree) {
          return _statusLabel(tree['healthStatus']) == 'NeedsAttention';
        }).length;

        return (
          total: total.toString(),
          healthy: healthy.toString(),
          needAttention: needAttention.toString(),
        );
      },
      loading: () => (total: '...', healthy: '...', needAttention: '...'),
      error: (_, __) => (total: '-', healthy: '-', needAttention: '-'),
    );

    return Scaffold(
      backgroundColor: Colors.grey[200],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => context.push('/scan'),
        child: const Icon(Icons.qr_code),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 20,
              vertical: 6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _navItem(
                    Icons.home,
                    context.tr('home'),
                    isActive: true,
                    compact: isCompact,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/my-trees'),
                    child: _navItem(
                      Icons.park,
                      context.tr('myTrees'),
                      compact: isCompact,
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 28 : 40),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/report'),
                    child: _navItem(
                      Icons.insert_chart,
                      context.tr('report'),
                      compact: isCompact,
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/profile'),
                    child: _navItem(
                      Icons.person,
                      context.tr('profile'),
                      compact: isCompact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    final greeting = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.agriculture, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${context.tr('namaste')}, $userName!',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    );

                    final actions = Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push(RoutePaths.activityLog),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: Text(context.tr('activityLog')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const NotificationSheet(),
                            );
                          },
                          icon: const Icon(Icons.notifications),
                          tooltip: context.tr('notifications'),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          greeting,
                          const SizedBox(height: 12),
                          actions,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: greeting),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SyncDetailsSheet(
                        isOnline: isOnline,
                        pendingCount: pendingSyncAsync.valueOrNull ?? 0,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFFDFF5E1)
                          : const Color(0xFFFFE0E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackVertically = constraints.maxWidth < 330;
                            final statusChip = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 5,
                                  backgroundColor:
                                      isOnline ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isOnline
                                      ? context.tr('online')
                                      : context.tr('offline'),
                                ),
                              ],
                            );

                            if (stackVertically) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('syncStatusPanel')),
                                  const SizedBox(height: 8),
                                  statusChip,
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.tr('syncStatusPanel')),
                                statusChip,
                              ],
                            );
                          },
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.sync),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pendingSyncAsync.when(
                                  data: (count) {
                                    if (isOnline && count == 0) {
                                      return 'Tag <-> Cloud Sync: ACTIVE\nAll local changes are synced.';
                                    }
                                    if (isOnline) {
                                      return 'Tag <-> Cloud Sync: ACTIVE\n$count item(s) are finishing sync now.';
                                    }
                                    return 'Working offline\n$count item(s) saved locally and waiting for sync.';
                                  },
                                  loading: () => 'Checking sync status...',
                                  error: (_, __) =>
                                      'Sync status is unavailable right now.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ResponsiveWrapGrid(
                  minChildWidth: 140,
                  maxColumns: 3,
                  children: [
                    _StatCard(
                      title: context.tr('myTrees'),
                      value: stats.total,
                      icon: Icons.park,
                      onTap: () => context.push('/my-trees'),
                    ),
                    _StatCard(
                      title: context.tr('healthy'),
                      value: stats.healthy,
                      icon: Icons.favorite,
                      onTap: () => context.push('/my-trees?filter=healthy'),
                    ),
                    _StatCard(
                      title: context.tr('needAttention'),
                      value: stats.needAttention,
                      icon: Icons.warning_amber_rounded,
                      warning: true,
                      onTap: () => context.push('/my-trees?filter=attention'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _WeatherSummaryCard(
                  weatherAsync: weatherAsync,
                  onRefresh: () => ref.invalidate(_dashboardWeatherProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    bool isActive = false,
    bool compact = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.green : Colors.black),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 11 : 12),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _dedupeTrees(List<Map<String, dynamic>> trees) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final tree in trees) {
      final docId = (tree[treeDocIdField] ?? '').toString().trim();
      final treeId = (tree['treeId'] ?? '').toString().trim();
      final key = docId.isNotEmpty ? docId : treeId;
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(tree);
    }

    return result;
  }

  String _statusLabel(dynamic status) {
    switch ((status ?? '').toString()) {
      case '0':
        return 'Healthy';
      case '1':
        return 'NeedsAttention';
      case '2':
        return 'AtRisk';
      default:
        return 'Healthy';
    }
  }
}

class _WeatherSummaryCard extends StatelessWidget {
  const _WeatherSummaryCard({
    required this.weatherAsync,
    required this.onRefresh,
  });

  final AsyncValue<_DashboardWeather> weatherAsync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final weather = weatherAsync.valueOrNull;

    if (weatherAsync.isLoading ||
        weatherAsync.hasValue ||
        weatherAsync.hasError) {
      return _LiveWeatherPanel(
        weather: weather,
        weatherAsync: weatherAsync,
        onRefresh: onRefresh,
        errorText: weatherAsync.hasError
            ? _friendlyWeatherError(weatherAsync.error!)
            : null,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather?.locationName ?? context.tr('currentLocation'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weatherAsync.when(
                        data: (weather) => weather.condition,
                        loading: () => context.tr('gettingWeather'),
                        error: (error, _) => _friendlyWeatherError(error),
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: context.tr('refreshWeather'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '32°C',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Sunny - good conditions for field work',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const ResponsiveWrapGrid(
            minChildWidth: 86,
            maxColumns: 4,
            spacing: 8,
            runSpacing: 8,
            children: [
              _WeatherMetric(
                icon: Icons.water_drop,
                label: 'Humidity',
                value: '55%',
              ),
              _WeatherMetric(
                icon: Icons.air,
                label: 'Wind',
                value: '12 km/h',
              ),
              _WeatherMetric(
                icon: Icons.grain,
                label: 'Rain',
                value: '0 mm',
              ),
              _WeatherMetric(
                icon: Icons.wb_twilight,
                label: 'UV',
                value: 'High',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _friendlyWeatherError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    if (message.isEmpty) return 'Unable to load weather right now.';
    return message;
  }
}

class _LiveWeatherPanel extends StatelessWidget {
  const _LiveWeatherPanel({
    required this.weather,
    required this.weatherAsync,
    required this.onRefresh,
    required this.errorText,
  });

  final _DashboardWeather? weather;
  final AsyncValue<_DashboardWeather> weatherAsync;
  final VoidCallback onRefresh;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather?.locationName ?? 'Current location',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weatherAsync.when(
                        data: (weather) => weather.condition,
                        loading: () => 'Getting location and weather...',
                        error: (_, __) =>
                            errorText ?? 'Unable to load weather right now.',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh weather',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            weather == null ? '--°C' : '${weather!.temperature.round()}°C',
            style: TextStyle(
              color: weatherAsync.hasError ? Colors.white70 : Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            weather?.advice ?? context.tr('weatherAfterAccess'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ResponsiveWrapGrid(
            minChildWidth: 86,
            maxColumns: 4,
            spacing: 8,
            runSpacing: 8,
            children: [
              _WeatherMetric(
                icon: Icons.water_drop,
                label: context.tr('humidity'),
                value: weather == null ? '--' : '${weather!.humidity.round()}%',
              ),
              _WeatherMetric(
                icon: Icons.air,
                label: context.tr('wind'),
                value: weather == null
                    ? '--'
                    : '${weather!.windSpeed.round()} km/h',
              ),
              _WeatherMetric(
                icon: Icons.grain,
                label: context.tr('rain'),
                value: weather == null
                    ? '--'
                    : '${weather!.rain.toStringAsFixed(1)} mm',
              ),
              _WeatherMetric(
                icon: Icons.cloud,
                label: context.tr('clouds'),
                value:
                    weather == null ? '--' : '${weather!.cloudCover.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool warning;
  final VoidCallback? onTap;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.warning = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFEED9B7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: warning ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              icon,
              size: 34,
              color: warning ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class SyncDetailsSheet extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const SyncDetailsSheet({
    super.key,
    required this.isOnline,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _sheetRow(
            'Status',
            isOnline ? 'Online' : 'Offline',
            color: isOnline ? Colors.green : Colors.orange,
          ),
          _sheetRow('Pending Uploads', '$pendingCount item(s)'),
          _sheetRow(
            'Mode',
            isOnline ? 'Cloud sync active' : 'Local storage only',
          ),
          _sheetRow(
            'Next Action',
            isOnline
                ? 'Pending data will sync automatically'
                : 'Reconnect internet to sync pending items',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetRow(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView(
              children: const [
                _NotificationSection(
                  title: 'Weather Alerts',
                  items: [
                    NotificationItem('Rain expected today', '2 mins ago'),
                    NotificationItem('High temperature warning', '1 hour ago'),
                  ],
                ),
                _NotificationSection(
                  title: 'Reminders',
                  items: [
                    NotificationItem('Scan pending trees today', '10 mins ago'),
                    NotificationItem('Review issue reports', '30 mins ago'),
                  ],
                ),
                _NotificationSection(
                  title: 'System Updates',
                  items: [
                    NotificationItem(
                        'Offline data will sync automatically', 'Just now'),
                    NotificationItem('Profile changes saved', '2 hours ago'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  final String title;
  final List<NotificationItem> items;

  const _NotificationSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _NotificationTile(item: item)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class NotificationItem {
  final String message;
  final String time;

  const NotificationItem(this.message, this.time);
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(item.message)),
          Text(
            item.time,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

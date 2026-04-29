import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers/connectivity_provider.dart';

class TreeMapScreen extends ConsumerWidget {
  final double lat;
  final double lng;
  final String title;

  const TreeMapScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.title = 'Tree Location',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = LatLng(lat, lng);
    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
            ),
            children: [
              if (isOnline)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.kaushalyanxt_rfid',
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (!isOnline)
            const _MapOfflineBanner(
              message: 'Map tiles are unavailable while the device is offline.',
            ),
        ],
      ),
    );
  }
}

class _MapOfflineBanner extends StatelessWidget {
  const _MapOfflineBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCFFFFFFF),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

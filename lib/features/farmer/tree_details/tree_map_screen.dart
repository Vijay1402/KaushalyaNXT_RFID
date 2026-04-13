import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TreeMapScreen extends StatelessWidget {
  final double lat;
  final double lng;

  const TreeMapScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tree Location"),
        backgroundColor: Colors.green,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate:
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.app',
          ),

          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
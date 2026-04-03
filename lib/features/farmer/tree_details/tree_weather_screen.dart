// ============================================================
//  lib/features/farmer/tree_details/tree_weather_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';

class TreeWeatherScreen extends StatelessWidget {
  final Tree tree;
  const TreeWeatherScreen({super.key, required this.tree});

  static const _green1 = Color(0xFF1E4D2B);
  static const _blue   = Color(0xFF1565C0);

  // Mock weekly weather data — replace with real API later
  static const List<Map<String, dynamic>> _weeklyWeather = [
    {'day': 'Mon', 'icon': Icons.wb_sunny,        'temp': '32°C', 'rain': '0 mm',  'humidity': '55%'},
    {'day': 'Tue', 'icon': Icons.cloud,            'temp': '28°C', 'rain': '2 mm',  'humidity': '70%'},
    {'day': 'Wed', 'icon': Icons.grain,            'temp': '25°C', 'rain': '12 mm', 'humidity': '85%'},
    {'day': 'Thu', 'icon': Icons.wb_cloudy,        'temp': '27°C', 'rain': '5 mm',  'humidity': '75%'},
    {'day': 'Fri', 'icon': Icons.wb_sunny,         'temp': '31°C', 'rain': '0 mm',  'humidity': '58%'},
    {'day': 'Sat', 'icon': Icons.wb_sunny,         'temp': '33°C', 'rain': '0 mm',  'humidity': '52%'},
    {'day': 'Sun', 'icon': Icons.thunderstorm,     'temp': '24°C', 'rain': '18 mm', 'humidity': '90%'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text('${tree.name} — Weather'),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current conditions card ──────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karnataka, India — Plot ${tree.plotNumber}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.wb_sunny, color: Colors.yellowAccent, size: 48),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('32°C', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                          Text('Sunny — Good for trees', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _currentStat(Icons.water_drop,    'Humidity',   '55%'),
                      _currentStat(Icons.air,            'Wind',       '12 km/h'),
                      _currentStat(Icons.grain,          'Rainfall',   '0 mm'),
                      _currentStat(Icons.wb_twilight,    'UV Index',   'High'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Weekly forecast ──────────────────────────────────
            const Text('7-Day Forecast',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A2E1C))),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
              ),
              child: Column(
                children: _weeklyWeather.asMap().entries.map((entry) {
                  final i = entry.key;
                  final w = entry.value;
                  return Column(
                    children: [
                      Row(children: [
                        SizedBox(width: 40, child: Text(w['day'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Icon(w['icon'] as IconData, color: Colors.orange, size: 22),
                        const SizedBox(width: 10),
                        Text(w['temp'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const Spacer(),
                        Icon(Icons.grain, color: Colors.blue.shade300, size: 14),
                        const SizedBox(width: 4),
                        Text(w['rain'] as String,
                            style: TextStyle(color: Colors.blue.shade600, fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.water_drop, color: Colors.teal.shade300, size: 14),
                        const SizedBox(width: 4),
                        Text(w['humidity'] as String,
                            style: TextStyle(color: Colors.teal.shade700, fontSize: 12)),
                      ]),
                      if (i < _weeklyWeather.length - 1)
                        Divider(height: 16, color: Colors.grey.shade100),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Tree impact note ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Conditions this week are favourable for growth. '
                      'Expect moderate rainfall on Wednesday and Sunday — '
                      'reduce irrigation accordingly.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
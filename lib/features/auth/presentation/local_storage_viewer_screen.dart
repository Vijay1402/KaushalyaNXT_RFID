import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageViewerScreen extends StatefulWidget {
  const LocalStorageViewerScreen({super.key});

  @override
  State<LocalStorageViewerScreen> createState() =>
      _LocalStorageViewerScreenState();
}

class _LocalStorageViewerScreenState extends State<LocalStorageViewerScreen> {
  late Future<_StorageData> _storageFuture;

  @override
  void initState() {
    super.initState();
    _storageFuture = _loadStorage();
  }

  Future<_StorageData> _loadStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();

    Map<String, dynamic>? user;
    final trees = <Map<String, dynamic>>[];
    final writtenTags = <Map<String, dynamic>>[];
    final others = <MapEntry<String, Object>>[];

    for (final key in keys) {
      final value = prefs.get(key);
      if (value == null) continue;

      dynamic decoded = value;
      if (value is String) {
        try {
          decoded = jsonDecode(value);
        } catch (_) {}
      }

      if (key == 'cached_user' && decoded is Map) {
        user = decoded.map((k, v) => MapEntry(k.toString(), v));
        continue;
      }

      if (key.startsWith('cached_trees_') && decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          trees.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
        continue;
      }

      if (key.startsWith('written_tag_') && decoded is Map) {
        writtenTags.add(decoded.map((k, v) => MapEntry(k.toString(), v)));
        continue;
      }

      others.add(MapEntry(key, value));
    }

    return _StorageData(
      user: user,
      trees: trees,
      writtenTags: writtenTags,
      others: others,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _storageFuture = _loadStorage();
    });
  }

  String _displayValue(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.trim().isEmpty) return '-';
    return value.toString();
  }

  String _prettyValue(dynamic value) {
    if (value == null) return '-';
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return value;
      }
    }
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Storage'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7F6),
      body: FutureBuilder<_StorageData>(
        future: _storageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load local storage: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.park_outlined,
                      label: 'Trees',
                      value: '${data.trees.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.nfc_outlined,
                      label: 'Written Tags',
                      value: '${data.writtenTags.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.storage_outlined,
                      label: 'Other Keys',
                      value: '${data.others.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.person_outline,
                title: 'User',
                child: data.user == null
                    ? const Text('No user stored')
                    : Column(
                        children: data.user!.entries
                            .map((entry) => _row(entry.key, entry.value))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.forest_outlined,
                title: 'Trees',
                child: data.trees.isEmpty
                    ? const Text('No trees stored')
                    : Column(
                        children:
                            data.trees.map((tree) => _treeCard(tree)).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.memory_outlined,
                title: 'Written Tags',
                child: data.writtenTags.isEmpty
                    ? const Text('No written tags stored')
                    : Column(
                        children: data.writtenTags
                            .map((tag) => _tagCard(tag))
                            .toList(),
                      ),
              ),
              if (data.others.isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(
                  icon: Icons.key_outlined,
                  title: 'Other Keys',
                  child: Column(
                    children: data.others
                        .map((entry) => ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(entry.key),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: SelectableText(
                                    _prettyValue(entry.value),
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _treeCard(Map<String, dynamic> tree) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayValue(tree['treeId'] ?? 'Unknown Tree'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _row('Owner', tree['ownerName'] ?? tree['farmerName']),
          _row('Species', tree['species']),
          _row('Location', tree['location']),
          _row('RFID', tree['rfid']),
        ],
      ),
    );
  }

  Widget _tagCard(Map<String, dynamic> tag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayValue(tag['treeId'] ?? tag['epc'] ?? 'Written Tag'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _row('EPC', tag['epc']),
          _row('Farmer', tag['farmerName']),
          _row('Age', tag['treeAgeYears']),
          _row('Yield', tag['lastYieldKg']),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(_displayValue(value)),
          ),
        ],
      ),
    );
  }
}

class _StorageData {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> trees;
  final List<Map<String, dynamic>> writtenTags;
  final List<MapEntry<String, Object>> others;

  const _StorageData({
    required this.user,
    required this.trees,
    required this.writtenTags,
    required this.others,
  });
}

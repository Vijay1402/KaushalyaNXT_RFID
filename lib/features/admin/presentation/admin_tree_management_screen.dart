import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/widgets/responsive_layout.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import '../../farm_manager/presentation/farm_manager_providers.dart';
import 'admin_management_forms.dart';
import 'admin_management_service.dart';
import 'admin_tree_detail_screen.dart';

class AdminTreeManagementScreen extends ConsumerStatefulWidget {
  const AdminTreeManagementScreen({super.key});

  @override
  ConsumerState<AdminTreeManagementScreen> createState() =>
      _AdminTreeManagementScreenState();
}

class _AdminTreeManagementScreenState
    extends ConsumerState<AdminTreeManagementScreen> {
  static const MethodChannel _fileSaveChannel = MethodChannel(
    'com.example.kaushalyanxt_rfid/files',
  );

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _databaseSectionKey = GlobalKey();

  String _search = '';
  bool _isAddingTree = false;
  bool _isBulkImporting = false;
  bool _isExporting = false;
  List<Map<String, dynamic>> _currentVisibleTrees =
      const <Map<String, dynamic>>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openTreeDetails(Map<String, dynamic> tree) {
    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    if (treeDocId.isEmpty) {
      _showMessage('This tree record is missing a document id.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminTreeDetailScreen(treeDocId: treeDocId),
      ),
    );
  }

  Future<void> _scrollToDatabaseSection() async {
    final targetContext = _databaseSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _addTree(FarmManagerOverviewData overview) async {
    final selectedFarm = overview.farms.length == 1
        ? overview.farms.first
        : await _selectFarm(
            title: 'Select Farm',
            farms: overview.farms,
          );
    if (!mounted) {
      return;
    }
    if (selectedFarm == null) {
      return;
    }

    final formData = await showAdminTreeFormDialog(
      context,
      farmName: selectedFarm.name,
      defaultFarmerName: selectedFarm.farmerName,
    );
    if (formData == null) {
      return;
    }

    setState(() {
      _isAddingTree = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).createTree(
            farmId: selectedFarm.id,
            farmName: selectedFarm.name,
            farmerName: selectedFarm.farmerName,
            farmerId: selectedFarm.farmerId,
            farmerEmail: selectedFarm.farmerEmail,
            data: formData,
          );

      if (!mounted) {
        return;
      }

      _showMessage('Tree added successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isAddingTree = false;
        });
      }
    }
  }

  Future<void> _bulkImportTrees(FarmManagerOverviewData overview) async {
    final selectedFarm = overview.farms.length == 1
        ? overview.farms.first
        : await _selectFarm(
            title: 'Bulk Import Farm',
            farms: overview.farms,
          );
    if (!mounted) {
      return;
    }
    if (selectedFarm == null) {
      return;
    }

    final rawInput = await _showBulkImportDialog(selectedFarm);
    if (rawInput == null) {
      return;
    }

    final rows = _parseBulkImportRows(rawInput);
    if (rows.isEmpty) {
      _showMessage('No valid tree rows were found to import.');
      return;
    }

    setState(() {
      _isBulkImporting = true;
    });

    try {
      final service = ref.read(adminManagementServiceProvider);
      for (final row in rows) {
        await service.createTree(
          farmId: selectedFarm.id,
          farmName: selectedFarm.name,
          farmerName: selectedFarm.farmerName,
          farmerId: selectedFarm.farmerId,
          farmerEmail: selectedFarm.farmerEmail,
          data: AdminTreeFormData(
            treeId: row.treeId,
            species: row.species,
            location: row.location,
            farmerName: row.farmerName.isEmpty
                ? selectedFarm.farmerName
                : row.farmerName,
            healthStatus: row.healthStatus,
            ageYears: row.ageYears,
            lastYieldKg: row.lastYieldKg,
            harvestMonth: row.harvestMonth,
            latitude: null,
            longitude: null,
            rfid: row.rfid,
            isScanned: row.rfid.isNotEmpty,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage('${rows.length} tree(s) imported successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Bulk import failed: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isBulkImporting = false;
        });
      }
    }
  }

  Future<void> _exportVisibleTrees() async {
    if (_currentVisibleTrees.isEmpty) {
      _showMessage('No visible trees are available to export.');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final rows = <List<String>>[
        <String>[
          'Tree ID',
          'Farm',
          'Assigned',
          'Location',
          'Status',
          'RFID',
          'Health',
          'Yield',
        ],
        ..._currentVisibleTrees.map(
          (tree) => <String>[
            _treeId(tree),
            _farmName(tree),
            _assignedName(tree),
            _treeLocation(tree),
            _treeLinkStatus(tree),
            firstNonEmptyString([tree['rfid']], fallback: 'Not tagged'),
            healthLabel(tree['healthStatus']),
            '${asDouble(tree['lastYieldKg'] ?? tree['yieldKg'])} kg',
          ],
        ),
      ];

      final csvContent = const ListToCsvConverter().convert(rows);
      final fileName =
          'admin_tree_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final savedPath = await _saveBytesToDownloads(
        fileName: fileName,
        mimeType: 'text/csv',
        bytes: utf8.encode(csvContent),
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        savedPath == null
            ? 'Tree data exported successfully.'
            : 'Tree data exported to $savedPath',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Export failed: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<String?> _saveBytesToDownloads({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (Platform.isAndroid) {
      try {
        final savedLocation = await _fileSaveChannel.invokeMethod<String>(
          'saveBytesToDownloads',
          <String, dynamic>{
            'fileName': fileName,
            'mimeType': mimeType,
            'bytes': Uint8List.fromList(bytes),
          },
        );
        if (savedLocation != null && savedLocation.trim().isNotEmpty) {
          return savedLocation;
        }
      } on PlatformException {
        // Fall back to filesystem export.
      }
    }

    final downloadsDirectory = await getDownloadsDirectory();
    final exportDirectory =
        downloadsDirectory ?? await getApplicationDocumentsDirectory();
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final file = File('${exportDirectory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<FarmManagerFarm?> _selectFarm({
    required String title,
    required List<FarmManagerFarm> farms,
  }) async {
    if (farms.isEmpty) {
      _showMessage('Add a farm first from the settings button.');
      return null;
    }

    final sortedFarms = List<FarmManagerFarm>.from(farms)
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );

    return showDialog<FarmManagerFarm>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: ResponsiveLayout.dialogWidth(context),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sortedFarms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final farm = sortedFarms[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    farm.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    farm.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, farm),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showBulkImportDialog(FarmManagerFarm farm) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Import Trees'),
          content: SizedBox(
            width: ResponsiveLayout.dialogWidth(context, maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm: ${farm.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste one tree per line using:\n'
                  'Tree ID, Species, Location, RFID, Farmer Name, Health, Age, Yield, Harvest Month',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Example:\n'
                  'Tree101, Jackfruit, Plot A, RFID101, Prakash, Healthy, 4, 12.5, July',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: 'Paste CSV rows here',
                    filled: true,
                    fillColor: const Color(0xFFF7FAF4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  List<_BulkImportTreeRow> _parseBulkImportRows(String rawInput) {
    final rows = <_BulkImportTreeRow>[];

    for (final line in const LineSplitter().convert(rawInput)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final columns = trimmed
          .split(',')
          .map((value) => value.trim())
          .toList(growable: false);
      if (columns.isEmpty) {
        continue;
      }

      final firstValue = columns.first.toLowerCase();
      if (firstValue == 'tree id' || firstValue == 'treeid') {
        continue;
      }

      final treeId = columns.isNotEmpty ? columns[0] : '';
      if (treeId.isEmpty) {
        continue;
      }

      rows.add(
        _BulkImportTreeRow(
          treeId: treeId,
          species: columns.length > 1 && columns[1].isNotEmpty
              ? columns[1]
              : 'Unknown',
          location: columns.length > 2 ? columns[2] : '',
          rfid: columns.length > 3 ? columns[3] : '',
          farmerName: columns.length > 4 ? columns[4] : '',
          healthStatus: _healthCode(columns.length > 5 ? columns[5] : ''),
          ageYears: columns.length > 6 ? int.tryParse(columns[6]) ?? 0 : 0,
          lastYieldKg:
              columns.length > 7 ? double.tryParse(columns[7]) ?? 0 : 0,
          harvestMonth: columns.length > 8 ? columns[8] : '',
        ),
      );
    }

    return rows;
  }

  String _healthCode(String rawHealth) {
    final normalized = rawHealth.trim().toLowerCase();
    switch (normalized) {
      case 'needs attention':
      case 'needsattention':
      case '1':
        return '1';
      case 'at risk':
      case 'atrisk':
      case '2':
        return '2';
      case 'critical':
      case 'sick':
      case '3':
        return '3';
      default:
        return '0';
    }
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String _treeId(Map<String, dynamic> tree) {
    return firstNonEmptyString(
      [tree['treeId'], tree['_docId']],
      fallback: 'Tree',
    );
  }

  String _farmName(Map<String, dynamic> tree) {
    return firstNonEmptyString(
      [tree['farmName'], tree['farm'], tree['farmId']],
      fallback: 'Unassigned Farm',
    );
  }

  String _assignedName(Map<String, dynamic> tree) {
    return firstNonEmptyString(
      [tree['ownerName'], tree['farmerName'], tree['userName']],
      fallback: 'Unassigned',
    );
  }

  String _treeLocation(Map<String, dynamic> tree) {
    return firstNonEmptyString(
      [tree['location'], tree['plotNumber'], tree['plot']],
      fallback: 'Location unavailable',
    );
  }

  String _treeLinkStatus(Map<String, dynamic> tree) {
    final hasLink = firstNonEmptyString(
      [tree['farmId'], tree['farmName'], tree['ownerName'], tree['farmerName']],
    ).isNotEmpty;
    return hasLink ? 'Linked' : 'Pending';
  }

  List<Map<String, dynamic>> _visibleTrees(List<Map<String, dynamic>> trees) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) {
      return trees;
    }

    return trees.where((tree) {
      final values = <String>[
        _treeId(tree),
        _farmName(tree),
        _assignedName(tree),
        _treeLocation(tree),
        firstNonEmptyString([tree['species']]),
        firstNonEmptyString([tree['rfid']]),
      ];

      return values.any((value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(globalFarmOverviewProvider);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAEA),
      body: SafeArea(
        child: overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load trees: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (overview) {
            final allTrees =
                List<Map<String, dynamic>>.from(overview.scopedTrees)
                  ..sort((left, right) {
                    final rightDate = parseDateTime(
                          right['updatedAt'] ??
                              right['lastinspectiondate'] ??
                              right['createdAt'],
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final leftDate = parseDateTime(
                          left['updatedAt'] ??
                              left['lastinspectiondate'] ??
                              left['createdAt'],
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return rightDate.compareTo(leftDate);
                  });

            final visibleTrees = _visibleTrees(allTrees);
            _currentVisibleTrees = visibleTrees;

            final totalTrees = allTrees.length;
            final taggedTrees = allTrees
                .where((tree) => firstNonEmptyString([tree['rfid']]).isNotEmpty)
                .length;
            final pendingTags = totalTrees - taggedTrees;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                10,
                horizontalPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF232322),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Tree Management',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF232322),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _search = value.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search Trees',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 34,
                          color: Color(0xFF444444),
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isAddingTree || _isBulkImporting)
                          ? null
                          : () => _addTree(overview),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF6750A4),
                        size: 34,
                      ),
                      label: Text(
                        _isAddingTree ? 'Adding Tree...' : 'Add New Tree',
                        style: const TextStyle(
                          color: Color(0xFF6750A4),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6AC16A),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent Trees',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _scrollToDatabaseSection,
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6750A4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveWrapGrid(
                    minChildWidth: 150,
                    maxColumns: 3,
                    spacing: 14,
                    children: [
                      _TreeStatCard(
                        backgroundColor: const Color(0xFF232322),
                        title: 'Total Trees',
                        value: '$totalTrees',
                      ),
                      _TreeStatCard(
                        backgroundColor: const Color(0xFF4CAF50),
                        title: 'RFID Tagged',
                        value: '$taggedTrees',
                      ),
                      _TreeStatCard(
                        backgroundColor: const Color(0xFFFF9800),
                        title: 'Pending Tags',
                        value: '$pendingTags',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ResponsiveWrapGrid(
                    minChildWidth: 170,
                    maxColumns: 2,
                    spacing: 18,
                    children: [
                      _ActionCapsuleButton(
                        label:
                            _isBulkImporting ? 'Importing...' : 'Bulk Import',
                        onTap: (_isBulkImporting || _isAddingTree)
                            ? null
                            : () => _bulkImportTrees(overview),
                      ),
                      _ActionCapsuleButton(
                        label: _isExporting ? 'Exporting...' : 'Export Data',
                        onTap: _isExporting ? null : _exportVisibleTrees,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    key: _databaseSectionKey,
                    child: const Text(
                      'Tree Management Database',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visibleTrees.isEmpty)
                    _EmptyTreeState(
                      message: allTrees.isEmpty
                          ? 'No trees are available yet. Add a tree to get started.'
                          : 'No trees match the current search.',
                    )
                  else
                    ...visibleTrees.map(
                      (tree) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _TreeDatabaseCard(
                          treeId: _treeId(tree),
                          farmName: _farmName(tree),
                          assignedName: _assignedName(tree),
                          location: _treeLocation(tree),
                          status: _treeLinkStatus(tree),
                          initials: _initialsFor(_assignedName(tree)),
                          onTap: () => _openTreeDetails(tree),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TreeStatCard extends StatelessWidget {
  const _TreeStatCard({
    required this.backgroundColor,
    required this.title,
    required this.value,
  });

  final Color backgroundColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Align(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCapsuleButton extends StatelessWidget {
  const _ActionCapsuleButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6AC16A),
        foregroundColor: const Color(0xFF6750A4),
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyTreeState extends StatelessWidget {
  const _EmptyTreeState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2FB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }
}

class _TreeDatabaseCard extends StatelessWidget {
  const _TreeDatabaseCard({
    required this.treeId,
    required this.farmName,
    required this.assignedName,
    required this.location,
    required this.status,
    required this.initials,
    required this.onTap,
  });

  final String treeId;
  final String farmName;
  final String assignedName;
  final String location;
  final String status;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final linked = status.toLowerCase() == 'linked';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F4FB),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      treeId,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: linked
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFD7F2D2),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFF5A3EA1),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farm: $farmName',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Assigned: $assignedName',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Location: $location',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF202124),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Status: $status',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 42,
                      color: Color(0xFF202124),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkImportTreeRow {
  const _BulkImportTreeRow({
    required this.treeId,
    required this.species,
    required this.location,
    required this.rfid,
    required this.farmerName,
    required this.healthStatus,
    required this.ageYears,
    required this.lastYieldKg,
    required this.harvestMonth,
  });

  final String treeId;
  final String species;
  final String location;
  final String rfid;
  final String farmerName;
  final String healthStatus;
  final int ageYears;
  final double lastYieldKg;
  final String harvestMonth;
}

String _initialsFor(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'NA';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}

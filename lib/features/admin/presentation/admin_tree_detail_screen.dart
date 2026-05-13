import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import 'admin_management_forms.dart';
import 'admin_management_service.dart';

class AdminTreeDetailScreen extends ConsumerStatefulWidget {
  const AdminTreeDetailScreen({
    super.key,
    required this.treeDocId,
  });

  final String treeDocId;

  @override
  ConsumerState<AdminTreeDetailScreen> createState() =>
      _AdminTreeDetailScreenState();
}

class _AdminTreeDetailScreenState extends ConsumerState<AdminTreeDetailScreen> {
  bool _isWorking = false;

  Future<void> _editTree(Map<String, dynamic> tree) async {
    final formData = await showAdminTreeFormDialog(
      context,
      farmName: firstNonEmptyString(
        [tree['farmName']],
        fallback: 'Farm',
      ),
      defaultFarmerName: firstNonEmptyString(
        [tree['ownerName'], tree['farmerName']],
        fallback: 'Farmer',
      ),
      initialData: AdminTreeFormData.fromTree(tree),
    );

    if (formData == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).updateTree(
            treeDocId: widget.treeDocId,
            farmId: (tree['farmId'] ?? '').toString().trim(),
            farmName: firstNonEmptyString(
              [tree['farmName']],
              fallback: 'Farm',
            ),
            farmerName: firstNonEmptyString(
              [tree['ownerName'], tree['farmerName']],
              fallback: 'Farmer',
            ),
            farmerId: firstNonEmptyString(
              [tree['farmerId'], tree['userId']],
            ),
            farmerEmail: firstNonEmptyString(
              [tree['farmerEmail'], tree['ownerEmail']],
            ),
            data: formData,
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tree updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _deleteTree(Map<String, dynamic> tree) async {
    final treeId = firstNonEmptyString([tree['treeId']], fallback: 'this tree');
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Tree'),
            content: Text(
              'Delete $treeId from this farm?\n\nThis also removes any issue '
              'records linked to the tree.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).deleteTree(
            treeDocId: widget.treeDocId,
            farmId: (tree['farmId'] ?? '').toString().trim(),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$treeId deleted successfully.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(treeDocumentProvider(widget.treeDocId));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Tree Details'),
      ),
      body: treeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load tree details: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (snapshot) {
          if (!snapshot.exists) {
            return const Center(
              child: Text('This tree no longer exists.'),
            );
          }

          final tree = <String, dynamic>{
            '_docId': snapshot.id,
            ...?snapshot.data(),
          };
          final treeId = firstNonEmptyString(
            [tree['treeId']],
            fallback: 'Tree',
          );
          final health = healthLabel(tree['healthStatus']);
          final horizontalPadding = ResponsiveLayout.pagePadding(context);

          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade800,
                      Colors.green.shade500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treeId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      firstNonEmptyString(
                        [tree['species']],
                        fallback: 'Unknown species',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: health,
                          color: healthColor(health),
                        ),
                        _InfoChip(
                          label: (tree['isScanned'] == true)
                              ? 'Scanned'
                              : 'Not scanned',
                          color: (tree['isScanned'] == true)
                              ? Colors.teal
                              : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isWorking)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Tree Profile',
                children: [
                  _DetailRow(
                    label: 'Tree ID',
                    value: treeId,
                  ),
                  _DetailRow(
                    label: 'Species',
                    value: firstNonEmptyString(
                      [tree['species']],
                      fallback: '-',
                    ),
                  ),
                  _DetailRow(
                    label: 'Farm',
                    value: firstNonEmptyString(
                      [tree['farmName']],
                      fallback: '-',
                    ),
                  ),
                  _DetailRow(
                    label: 'Farmer',
                    value: firstNonEmptyString(
                      [tree['ownerName'], tree['farmerName']],
                      fallback: '-',
                    ),
                  ),
                  _DetailRow(
                    label: 'Location',
                    value: firstNonEmptyString(
                      [tree['location'], tree['plotNumber'], tree['plot']],
                      fallback: '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Health & Yield',
                children: [
                  _DetailRow(label: 'Health', value: health),
                  _DetailRow(
                    label: 'Tree Age',
                    value: '${asInt(tree['treeAge'] ?? tree['age'])} years',
                  ),
                  _DetailRow(
                    label: 'Last Yield',
                    value:
                        '${asDouble(tree['lastYieldKg'] ?? tree['yieldKg'])} kg',
                  ),
                  _DetailRow(
                    label: 'Harvest Month',
                    value: firstNonEmptyString(
                      [tree['harvestMonth']],
                      fallback: '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Device & Coordinates',
                children: [
                  _DetailRow(
                    label: 'RFID',
                    value: firstNonEmptyString([tree['rfid']], fallback: '-'),
                  ),
                  _DetailRow(
                    label: 'Latitude',
                    value: (tree['latitude'] ?? '-').toString(),
                  ),
                  _DetailRow(
                    label: 'Longitude',
                    value: (tree['longitude'] ?? '-').toString(),
                  ),
                  _DetailRow(
                    label: 'Document ID',
                    value: widget.treeDocId,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ResponsiveWrapGrid(
                minChildWidth: 150,
                maxColumns: 2,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : () => _editTree(tree),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Tree'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isWorking ? null : () => _deleteTree(tree),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Tree'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
    final isCompact = ResponsiveLayout.isCompact(context, breakpoint: 360);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/responsive_layout.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import '../../farm_manager/presentation/farm_manager_providers.dart';
import 'admin_farm_detail_screen.dart';
import 'admin_management_forms.dart';
import 'admin_management_service.dart';
import 'admin_tree_management_screen.dart';

class AdminFarmManagementScreen extends ConsumerStatefulWidget {
  const AdminFarmManagementScreen({super.key});

  @override
  ConsumerState<AdminFarmManagementScreen> createState() =>
      _AdminFarmManagementScreenState();
}

class _AdminFarmManagementScreenState
    extends ConsumerState<AdminFarmManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  bool _isWorking = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addFarm() async {
    final formData = await showAdminFarmFormDialog(context);
    if (formData == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await ref.read(adminManagementServiceProvider).createFarm(formData);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm added successfully.')),
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

  void _openFarm(String farmId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminFarmDetailScreen(farmId: farmId),
      ),
    );
  }

  void _openTrees() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminTreeManagementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(globalFarmOverviewProvider);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      body: SafeArea(
        child: overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load farms: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (overview) {
            final farms = overview.farms;
            final treeDocs = overview.treeDocs;
            final issues = overview.issues;
            final filteredFarms = farms.where((farm) {
              final query = _search.trim().toLowerCase();
              if (query.isEmpty) {
                return true;
              }
              return farm.name.toLowerCase().contains(query) ||
                  farm.location.toLowerCase().contains(query);
            }).toList(growable: false);
            final averageHealth = farms.isEmpty
                ? 0
                : (farms
                            .map((farm) => farm.healthPercent)
                            .reduce((left, right) => left + right) /
                        farms.length)
                    .round();

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Farm Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E5631),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    14,
                    horizontalPadding,
                    0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search farms or locations',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    0,
                  ),
                  child: ResponsiveWrapGrid(
                    minChildWidth: 140,
                    maxColumns: 2,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryCard(
                        title: 'All Farms',
                        value: '${farms.length}',
                        subtitle: 'Managed farms',
                        color: const Color(0xFF1E5631),
                      ),
                      _SummaryCard(
                        title: 'Trees',
                        value: '${treeDocs.length}',
                        subtitle: 'Across every farm',
                        color: Colors.green.shade700,
                        onTap: _openTrees,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    0,
                  ),
                  child: ResponsiveWrapGrid(
                    minChildWidth: 140,
                    maxColumns: 2,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryCard(
                        title: 'Health',
                        value: '$averageHealth%',
                        subtitle: 'Average farm health',
                        color: Colors.teal.shade700,
                      ),
                      _SummaryCard(
                        title: 'Issues',
                        value: '${issues.length}',
                        subtitle: 'Visible to admin',
                        color: issues.isEmpty
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isWorking ? null : _addFarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add_business_outlined),
                      label: Text(
                        _isWorking ? 'Working...' : 'Add Farm',
                      ),
                    ),
                  ),
                ),
                if (_isWorking)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredFarms.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              farms.isEmpty
                                  ? 'No farms are available yet.'
                                  : 'No farms match the current search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            24,
                          ),
                          itemCount: filteredFarms.length,
                          itemBuilder: (context, index) {
                            final farm = filteredFarms[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FarmTile(
                                farm: farm,
                                onTap: () => _openFarm(farm.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5631),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmTile extends StatelessWidget {
  const _FarmTile({
    required this.farm,
    required this.onTap,
  });

  final FarmManagerFarm farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grid_on, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farm.location,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: '${farm.totalTrees} trees',
                        color: Colors.green.shade700,
                      ),
                      _InfoChip(
                        label: '${farm.alertCount} alerts',
                        color: farm.alertCount == 0
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

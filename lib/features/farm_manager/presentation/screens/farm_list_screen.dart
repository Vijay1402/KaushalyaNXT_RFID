import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../farm_manager_data.dart';
import '../farm_manager_providers.dart';

class FarmListScreen extends ConsumerStatefulWidget {
  const FarmListScreen({super.key});

  @override
  ConsumerState<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends ConsumerState<FarmListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<int> _pendingSyncFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _pendingSyncFuture = _loadPendingSyncCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<int> _loadPendingSyncCount() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return 0;

    final cache = LocalCacheService();
    final pendingTrees = await cache.getPendingTreeSyncs(user.uid);
    final pendingIssues = await cache.getPendingIssues(user.uid);
    return pendingTrees.length + pendingIssues.length;
  }

  Future<void> _refreshSyncInfo() async {
    setState(() {
      _pendingSyncFuture = _loadPendingSyncCount();
    });
    await _pendingSyncFuture;
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(farmManagerOverviewProvider);
    final horizontalPadding = ResponsiveLayout.pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Text(context.tr('Farm Directory')),
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load farms: $error',
          ),
        ),
        data: (overview) {
          final scope = overview.scope;
          final scopedTrees = overview.scopedTrees;
          final farms = overview.farms;
          final filteredFarms = farms.where((farm) {
            final query = _search.trim().toLowerCase();
            if (query.isEmpty) return true;
            return farm.name.toLowerCase().contains(query) ||
                farm.location.toLowerCase().contains(query) ||
                farm.farmerName.toLowerCase().contains(query);
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
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  children: [
                    _SearchField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _search = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _SyncPanel(
                      pendingSyncFuture: _pendingSyncFuture,
                      onRefresh: _refreshSyncInfo,
                    ),
                    const SizedBox(height: 12),
                    if (!scope.hasLinkedFarmers)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Text(
                          scope.managerCode.isEmpty
                              ? 'No farmers are linked to this manager account yet.'
                              : 'No farmers are linked to manager code ${scope.managerCode} yet. Once a farmer uses this code, their farms and trees will appear here.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (!scope.hasLinkedFarmers) const SizedBox(height: 12),
                    ResponsiveWrapGrid(
                      minChildWidth: 150,
                      maxColumns: 2,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _SummaryCard(
                          icon: Icons.agriculture_outlined,
                          title: 'Total Farms',
                          value: '${farms.length}',
                        ),
                        _SummaryCard(
                          icon: Icons.eco_outlined,
                          title: 'Avg Health',
                          value: '$averageHealth%',
                        ),
                        _SummaryCard(
                          icon: Icons.park_outlined,
                          title: 'Total Trees',
                          value: '${scopedTrees.length}',
                          onTap: () {
                            context.push(
                              RoutePaths.farmManagerTrees,
                            );
                          },
                        ),
                        _SummaryCard(
                          icon: Icons.groups_2_outlined,
                          title: 'Farmers',
                          value: '${uniqueFarmerCount(scopedTrees)}',
                          onTap: () {
                            context.push(
                              RoutePaths.farmManagerFarmers,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshSyncInfo,
                  child: filteredFarms.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 80),
                            _EmptyState(
                              title: scope.shouldFilter
                                  ? 'No managed farms found'
                                  : 'No farms found',
                              message: scope.shouldFilter
                                  ? scope.hasLinkedFarmers
                                      ? 'No farm records were matched for the farmers linked to this manager yet.'
                                      : scope.managerCode.isEmpty
                                          ? 'No farmers are linked to this manager account yet.'
                                          : 'Ask the farmer to register or log in using manager code ${scope.managerCode} to see their farms here.'
                                  : 'Try a different search or add farm data to Firestore.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            20,
                          ),
                          itemCount: filteredFarms.length,
                          itemBuilder: (context, index) {
                            final farm = filteredFarms[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == filteredFarms.length - 1 ? 0 : 14,
                              ),
                              child: _FarmCard(farm: farm),
                            );
                          },
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search farms, locations, or farmers',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    required this.pendingSyncFuture,
    required this.onRefresh,
  });

  final Future<int> pendingSyncFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged,
      initialData: ConnectivityResult.mobile,
      builder: (context, connectivitySnapshot) {
        final connectivity =
            connectivitySnapshot.data ?? ConnectivityResult.none;
        final isOnline = connectivity != ConnectivityResult.none;

        return FutureBuilder<int>(
          future: pendingSyncFuture,
          builder: (context, pendingSnapshot) {
            final pendingCount = pendingSnapshot.data ?? 0;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 320;
                      final title = Row(
                        children: [
                          Icon(
                            isOnline
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off,
                            color:
                                isOnline ? Colors.green.shade700 : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isOnline
                                  ? 'Sync connected'
                                  : 'Offline mode active',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      );

                      if (!isCompact) {
                        return Row(
                          children: [
                            Expanded(child: title),
                            TextButton(
                              onPressed: onRefresh,
                              child: const Text('Refresh'),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: onRefresh,
                              child: const Text('Refresh'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pendingCount == 0
                        ? 'All local tree and issue updates are synced.'
                        : '$pendingCount local changes are waiting to sync.',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green.shade700),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.green.shade700,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
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

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.farm});

  final FarmManagerFarm farm;

  void _openFarmerManagement(BuildContext context) {
    context.push(
      '${RoutePaths.farmManagerFarmers}?farmerId='
      '${Uri.encodeComponent(farm.farmerId)}&farmerName='
      '${Uri.encodeComponent(farm.farmerName)}&farmId='
      '${Uri.encodeComponent(farm.id)}&farmLabel='
      '${Uri.encodeComponent(farm.name)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        context.push(RoutePaths.farmManagerFarmDetails, extra: farm);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade700,
                        Colors.green.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initialsFor(farm.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              farm.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        farm.location,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatChip(
                            icon: Icons.park_outlined,
                            label: '${farm.totalTrees} trees',
                            color: Colors.green.shade700,
                          ),
                          _StatChip(
                            icon: Icons.favorite_outline,
                            label: '${farm.healthPercent}% healthy',
                            color: Colors.teal.shade700,
                          ),
                          _StatChip(
                            icon: Icons.warning_amber_rounded,
                            label: farm.alertCount == 0
                                ? 'No alerts'
                                : '${farm.alertCount} alerts',
                            color: farm.alertCount == 0
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ResponsiveWrapGrid(
              minChildWidth: 132,
              maxColumns: 3,
              spacing: 8,
              runSpacing: 8,
              children: [
                _BottomMetric(
                  label: 'Farmer',
                  value: farm.farmerName,
                  highlight: true,
                  onTap: () => _openFarmerManagement(context),
                ),
                _BottomMetric(
                  label: 'Scanned',
                  value: '${farm.scannedTrees}/${farm.totalTrees}',
                ),
                _BottomMetric(
                  label: 'Area',
                  value:
                      farm.areaAcres <= 0 ? 'Not set' : '${farm.areaAcres} ac',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomMetric extends StatelessWidget {
  const _BottomMetric({
    required this.label,
    required this.value,
    this.onTap,
    this.highlight = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.green.shade800 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.green.shade700,
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: content,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.agriculture_outlined,
            size: 48,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

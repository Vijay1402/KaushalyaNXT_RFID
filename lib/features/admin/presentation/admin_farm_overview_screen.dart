import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import '../../farm_manager/presentation/farm_manager_providers.dart';

final adminFarmOverviewProvider =
    FutureProvider.autoDispose<AdminFarmOverviewData>((ref) async {
  final user = ref.read(authStateProvider).user;
  final firestore = ref.read(firestoreProvider);

  if (ref.read(firebaseAuthProvider).currentUser == null) {
    return AdminFarmOverviewData.empty(user: user);
  }

  final overview = await ref.read(globalFarmOverviewProvider.future);
  final treeById = <String, Map<String, dynamic>>{};
  final treeByDocId = <String, Map<String, dynamic>>{};

  for (final tree in overview.scopedTrees) {
    final treeId = (tree['treeId'] ?? '').toString().trim().toLowerCase();
    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    if (treeId.isNotEmpty) {
      treeById[treeId] = tree;
    }
    if (treeDocId.isNotEmpty) {
      treeByDocId[treeDocId] = tree;
    }
  }

  final scans = await _loadAdminScans(
    firestore: firestore,
    treeById: treeById,
  );
  final issues = _loadAdminIssues(
    issues: overview.issues,
    treeByDocId: treeByDocId,
  );
  final harvests = await _loadAdminHarvests(
    firestore: firestore,
    treeById: treeById,
  );

  final activities = <AdminFarmActivity>[
    ...scans,
    ...issues,
    ...harvests,
  ]..sort((left, right) => right.eventDate.compareTo(left.eventDate));

  return AdminFarmOverviewData(
    user: user,
    totalEvents: activities.length,
    scanCount: scans.length,
    issueCount: issues.length,
    harvestCount: harvests.length,
    activities: activities.take(5).toList(growable: false),
    allActivities: activities,
  );
});

class AdminFarmOverviewScreen extends ConsumerWidget {
  const AdminFarmOverviewScreen({super.key});

  static const Color greenDark = Color(0xFF2F8A3A);
  static const Color greenMid = Color(0xFF3E9747);
  static const Color panelTint = Color(0xFFEEF5E4);
  static const Color textDark = Color(0xFF1E2C1F);
  static const Color textMuted = Color(0xFF8A9487);
  static const Color border = Color(0xFFDCE8CF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminFarmOverviewProvider);

    return Scaffold(
      backgroundColor: greenDark,
      body: SafeArea(
        child: _ResponsiveScreenFrame(
          child: overviewAsync.when(
            data: (data) => _OverviewBody(data: data),
            loading: () => const _OverviewLoading(),
            error: (error, _) => _OverviewError(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminFarmOverviewProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.data});

  final AdminFarmOverviewData data;

  @override
  Widget build(BuildContext context) {
    final stats = <_OverviewStat>[
      _OverviewStat(
        icon: Icons.spa_rounded,
        iconColor: const Color(0xFF7DAE49),
        iconBackground: const Color(0xFFDDF1C9),
        value: _formatCount(data.totalEvents),
        label: 'Total Events',
        filter: AdminFarmActivityType.all,
      ),
      _OverviewStat(
        icon: Icons.qr_code_2_rounded,
        iconColor: const Color(0xFF67788C),
        iconBackground: const Color(0xFFE4ECF8),
        value: _formatCount(data.scanCount),
        label: 'Scans',
        filter: AdminFarmActivityType.scan,
      ),
      _OverviewStat(
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFC37D8F),
        iconBackground: const Color(0xFFF9E1E9),
        value: _formatCount(data.issueCount),
        label: 'Issues',
        filter: AdminFarmActivityType.issue,
      ),
      _OverviewStat(
        icon: Icons.agriculture_rounded,
        iconColor: const Color(0xFFD7A41B),
        iconBackground: const Color(0xFFFCF4D5),
        value: _formatCount(data.harvestCount),
        label: 'Harvests',
        filter: AdminFarmActivityType.harvest,
      ),
    ];

    return Column(
      children: [
        _OverviewHeader(
          userName: _greetingName(data.user),
          onBack: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Container(
            color: AdminFarmOverviewScreen.panelTint,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
              children: [
                const _SectionLabel(label: 'SUMMARY'),
                const SizedBox(height: 10),
                ResponsiveWrapGrid(
                  minChildWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  runSpacing: 10,
                  children: stats
                      .map(
                        (stat) => _SummaryCard(
                          stat: stat,
                          onTap: () => _openRecords(context, stat.filter),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                const _SectionLabel(label: 'RECENT ACTIVITIES'),
                const SizedBox(height: 10),
                if (data.activities.isEmpty)
                  const _EmptyStateCard(
                    title: 'No activity found',
                    subtitle:
                        'Recent scan, issue, and harvest entries will show here.',
                  )
                else
                  ...data.activities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(
                        activity: activity,
                        onTap: () => _openDetails(context, activity),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openRecords(BuildContext context, AdminFarmActivityType filter) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminFarmOverviewRecordsScreen(
          data: data,
          initialFilter: filter,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, AdminFarmActivity activity) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminFarmRecordDetailScreen(activity: activity),
      ),
    );
  }
}

class AdminFarmOverviewRecordsScreen extends StatefulWidget {
  const AdminFarmOverviewRecordsScreen({
    super.key,
    required this.data,
    this.initialFilter = AdminFarmActivityType.all,
  });

  final AdminFarmOverviewData data;
  final AdminFarmActivityType initialFilter;

  @override
  State<AdminFarmOverviewRecordsScreen> createState() =>
      _AdminFarmOverviewRecordsScreenState();
}

class _AdminFarmOverviewRecordsScreenState
    extends State<AdminFarmOverviewRecordsScreen> {
  late final TextEditingController _searchController;
  late AdminFarmActivityType _selectedFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final records =
        widget.data.filteredActivities(_selectedFilter).where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.searchText.contains(query);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AdminFarmOverviewScreen.greenDark,
      body: SafeArea(
        child: _ResponsiveScreenFrame(
          child: Column(
            children: [
              _SubPageHeader(
                title: 'Search Records',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  color: AdminFarmOverviewScreen.panelTint,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by Farm ID, Tree ID, Farmer...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF859284),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All',
                              selected:
                                  _selectedFilter == AdminFarmActivityType.all,
                              onTap: () {
                                setState(() {
                                  _selectedFilter = AdminFarmActivityType.all;
                                });
                              },
                            ),
                            _FilterPill(
                              label: 'Scan',
                              selected:
                                  _selectedFilter == AdminFarmActivityType.scan,
                              onTap: () {
                                setState(() {
                                  _selectedFilter = AdminFarmActivityType.scan;
                                });
                              },
                            ),
                            _FilterPill(
                              label: 'Issues',
                              selected: _selectedFilter ==
                                  AdminFarmActivityType.issue,
                              onTap: () {
                                setState(() {
                                  _selectedFilter = AdminFarmActivityType.issue;
                                });
                              },
                            ),
                            _FilterPill(
                              label: 'Harvest',
                              selected: _selectedFilter ==
                                  AdminFarmActivityType.harvest,
                              onTap: () {
                                setState(() {
                                  _selectedFilter =
                                      AdminFarmActivityType.harvest;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (records.isEmpty)
                        const _EmptyStateCard(
                          title: 'No records found',
                          subtitle: 'Try another search or filter.',
                        )
                      else
                        ...records.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecordCard(
                              activity: activity,
                              onTap: () => _openRecordDetails(activity),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRecordDetails(AdminFarmActivity activity) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminFarmRecordDetailScreen(activity: activity),
      ),
    );
  }
}

class AdminFarmRecordDetailScreen extends ConsumerWidget {
  const AdminFarmRecordDetailScreen({
    super.key,
    required this.activity,
  });

  final AdminFarmActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraEntries = activity.extraDetails.entries.toList(growable: false);

    return Scaffold(
      backgroundColor: AdminFarmOverviewScreen.greenDark,
      body: SafeArea(
        child: _ResponsiveScreenFrame(
          child: Column(
            children: [
              _SubPageHeader(
                title: 'Record Details',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  color: AdminFarmOverviewScreen.panelTint,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AdminFarmOverviewScreen.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 280;
                                if (!isCompact) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activity.recordTitle,
                                          style: const TextStyle(
                                            color: AdminFarmOverviewScreen
                                                .greenDark,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _TypeBadge(type: activity.type),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.recordTitle,
                                      style: const TextStyle(
                                        color:
                                            AdminFarmOverviewScreen.greenDark,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _TypeBadge(type: activity.type),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            _DetailRow(
                              label: 'TREE ID',
                              value: activity.treeId,
                            ),
                            _DetailRow(
                              label: 'FARM ID',
                              value: activity.farmId,
                            ),
                            _DetailRow(
                              label: 'FARMER NAME',
                              value: activity.farmerName,
                              highlight: activity.farmerName.isNotEmpty,
                              onTap: activity.farmerName.isEmpty
                                  ? null
                                  : () => _showFarmerInfoSheet(
                                        context,
                                        ref,
                                      ),
                            ),
                            _DetailRow(
                              label: 'LOCATION',
                              value: activity.location,
                            ),
                            _DetailRow(
                              label: 'EVENT',
                              value: activity.title,
                            ),
                            _DetailRow(
                              label: 'TYPE',
                              value: activity.type.badgeLabel,
                            ),
                            _DetailRow(
                              label: 'TIME',
                              value: _fullDateTime(activity.eventDate),
                              isLast: extraEntries.isEmpty,
                            ),
                            for (var index = 0;
                                index < extraEntries.length;
                                index++)
                              _DetailRow(
                                label: extraEntries[index].key,
                                value: extraEntries[index].value,
                                isLast: index == extraEntries.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFarmerInfoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FarmerInfoSheet(
          future: _loadFarmerProfile(
            ref.read(firestoreProvider),
            activity.farmerName,
          ),
          fallbackName: activity.farmerName,
        );
      },
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.userName,
    required this.onBack,
  });

  final String userName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminFarmOverviewScreen.greenDark,
            AdminFarmOverviewScreen.greenMid,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                visualDensity: VisualDensity.compact,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white12,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                '9:41',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'FarmTrack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Good morning, $userName',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Farm Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 33,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubPageHeader extends StatelessWidget {
  const _SubPageHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminFarmOverviewScreen.greenDark,
            AdminFarmOverviewScreen.greenMid,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                visualDensity: VisualDensity.compact,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white12,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 6, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                '9:41',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'FarmTrack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewLoading extends StatelessWidget {
  const _OverviewLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AdminFarmOverviewScreen.greenDark,
      ),
    );
  }
}

class _ResponsiveScreenFrame extends StatelessWidget {
  const _ResponsiveScreenFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth <= 430 ? constraints.maxWidth : 420.0;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: ColoredBox(
              color: Colors.white,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load farm overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6D6D6D)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AdminFarmOverviewScreen.greenMid,
        fontSize: 12,
        letterSpacing: 2.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stat,
    required this.onTap,
  });

  final _OverviewStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 136),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminFarmOverviewScreen.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: stat.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stat.icon, color: stat.iconColor, size: 20),
              ),
              const SizedBox(height: 26),
              Text(
                stat.value,
                style: const TextStyle(
                  color: AdminFarmOverviewScreen.greenDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.label,
                style: const TextStyle(
                  color: AdminFarmOverviewScreen.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onTap,
  });

  final AdminFarmActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminFarmOverviewScreen.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 260;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: AdminFarmOverviewScreen.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activity.subtitle,
                    style: const TextStyle(
                      color: AdminFarmOverviewScreen.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );

              if (!isCompact) {
                return Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: activity.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    Text(
                      _timeAgo(activity.eventDate),
                      style: const TextStyle(
                        color: AdminFarmOverviewScreen.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: activity.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(activity.eventDate),
                    style: const TextStyle(
                      color: AdminFarmOverviewScreen.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminFarmOverviewScreen.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: AdminFarmOverviewScreen.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminFarmOverviewScreen.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminFarmOverviewScreen.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.activity,
    required this.onTap,
  });

  final AdminFarmActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminFarmOverviewScreen.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 280;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.recordTitle,
                    style: const TextStyle(
                      color: AdminFarmOverviewScreen.greenDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activity.farmerName.isEmpty
                        ? 'Unknown Farmer'
                        : activity.farmerName,
                    style: const TextStyle(
                      color: AdminFarmOverviewScreen.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: Color(0xFFE6768E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.locationLabel,
                          style: const TextStyle(
                            color: AdminFarmOverviewScreen.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (!isCompact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    _TypeBadge(type: activity.type),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 10),
                  _TypeBadge(type: activity.type),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AdminFarmOverviewScreen.greenDark : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AdminFarmOverviewScreen.greenDark
                  : AdminFarmOverviewScreen.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? Colors.white : AdminFarmOverviewScreen.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final AdminFarmActivityType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: type.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.badgeLabel,
        style: TextStyle(
          color: type.badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isLast;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context, breakpoint: 340);

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE7ECE1)),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF97A392),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onTap,
              child: Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                  color: highlight
                      ? AdminFarmOverviewScreen.greenDark
                      : AdminFarmOverviewScreen.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  decoration: onTap != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE7ECE1)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF97A392),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                  color: highlight
                      ? AdminFarmOverviewScreen.greenDark
                      : AdminFarmOverviewScreen.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  decoration: onTap != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerInfoSheet extends StatelessWidget {
  const _FarmerInfoSheet({
    required this.future,
    required this.fallbackName,
  });

  final Future<AdminFarmerProfile?> future;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      child: FutureBuilder<AdminFarmerProfile?>(
        future: future,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final name = (profile?.name ?? fallbackName).trim();
          final autoId = (profile?.docId ?? '').trim();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 42,
                  child: Divider(
                    thickness: 4,
                    color: Color(0xFFD6D6D6),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'FARMER INFO',
                style: TextStyle(
                  color: AdminFarmOverviewScreen.greenMid,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFDDF1D8),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AdminFarmOverviewScreen.greenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Unknown Farmer' : name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AdminFarmOverviewScreen.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile == null
                              ? 'Farmer record not found'
                              : 'Registered ${profile.roleLabel}',
                          style: const TextStyle(
                            color: AdminFarmOverviewScreen.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ProfileField(
                label: 'AUTO ID',
                value: autoId.isEmpty ? 'No auto ID found' : autoId,
                trailing: autoId.isEmpty
                    ? null
                    : FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: autoId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Auto ID copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminFarmOverviewScreen.greenDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
              if ((profile?.email ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _ProfileField(label: 'EMAIL', value: profile!.email),
              ],
              if ((profile?.phone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _ProfileField(label: 'PHONE', value: profile!.phone),
              ],
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context, breakpoint: 340);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminFarmOverviewScreen.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminFarmOverviewScreen.border),
          ),
          child: isCompact && trailing != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AdminFarmOverviewScreen.greenDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: AdminFarmOverviewScreen.greenDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
        ),
      ],
    );
  }
}

class _OverviewStat {
  const _OverviewStat({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
    required this.filter,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;
  final AdminFarmActivityType filter;
}

class AdminFarmOverviewData {
  const AdminFarmOverviewData({
    required this.user,
    required this.totalEvents,
    required this.scanCount,
    required this.issueCount,
    required this.harvestCount,
    required this.activities,
    required this.allActivities,
  });

  final UserModel? user;
  final int totalEvents;
  final int scanCount;
  final int issueCount;
  final int harvestCount;
  final List<AdminFarmActivity> activities;
  final List<AdminFarmActivity> allActivities;

  factory AdminFarmOverviewData.empty({UserModel? user}) {
    return AdminFarmOverviewData(
      user: user,
      totalEvents: 0,
      scanCount: 0,
      issueCount: 0,
      harvestCount: 0,
      activities: const [],
      allActivities: const [],
    );
  }

  List<AdminFarmActivity> filteredActivities(AdminFarmActivityType filter) {
    if (filter == AdminFarmActivityType.all) {
      return allActivities;
    }
    return allActivities
        .where((item) => item.type == filter)
        .toList(growable: false);
  }
}

class AdminFarmerProfile {
  const AdminFarmerProfile({
    required this.docId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String docId;
  final String name;
  final String email;
  final String phone;
  final String role;

  String get roleLabel {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'admin') {
      return 'Admin';
    }
    if (normalized == 'farm_manager') {
      return 'Farm Manager';
    }
    return 'Farmer';
  }
}

class AdminFarmActivity {
  const AdminFarmActivity({
    required this.type,
    required this.treeId,
    required this.farmId,
    required this.farmerName,
    required this.location,
    required this.title,
    required this.subtitle,
    required this.eventDate,
    required this.dotColor,
    required this.extraDetails,
  });

  final AdminFarmActivityType type;
  final String treeId;
  final String farmId;
  final String farmerName;
  final String location;
  final String title;
  final String subtitle;
  final DateTime eventDate;
  final Color dotColor;
  final Map<String, String> extraDetails;

  String get recordTitle {
    final tree = treeId.isEmpty ? '-' : treeId;
    final farm = farmId.isEmpty ? '-' : farmId;
    return '$tree - $farm';
  }

  String get locationLabel =>
      location.isEmpty ? 'Location unavailable' : location;

  String get searchText {
    return [
      treeId,
      farmId,
      farmerName,
      location,
      title,
      subtitle,
      ...extraDetails.values,
    ].join(' ').toLowerCase();
  }
}

enum AdminFarmActivityType {
  all,
  scan,
  issue,
  harvest;

  String get badgeLabel {
    switch (this) {
      case AdminFarmActivityType.all:
        return 'ALL';
      case AdminFarmActivityType.scan:
        return 'SCAN';
      case AdminFarmActivityType.issue:
        return 'ISSUE';
      case AdminFarmActivityType.harvest:
        return 'HARVEST';
    }
  }

  Color get badgeColor {
    switch (this) {
      case AdminFarmActivityType.all:
        return const Color(0xFF61727A);
      case AdminFarmActivityType.scan:
        return const Color(0xFF2D78D4);
      case AdminFarmActivityType.issue:
        return const Color(0xFFD84D68);
      case AdminFarmActivityType.harvest:
        return const Color(0xFF41974D);
    }
  }

  Color get badgeBackground {
    switch (this) {
      case AdminFarmActivityType.all:
        return const Color(0xFFEAF0EE);
      case AdminFarmActivityType.scan:
        return const Color(0xFFE7F2FE);
      case AdminFarmActivityType.issue:
        return const Color(0xFFFBE7EC);
      case AdminFarmActivityType.harvest:
        return const Color(0xFFE3F3E4);
    }
  }
}

Future<List<AdminFarmActivity>> _loadAdminScans({
  required FirebaseFirestore firestore,
  required Map<String, Map<String, dynamic>> treeById,
}) async {
  final docs = await _fetchRecentDocs(
    firestore.collection('scan_history'),
    orderFields: const ['savedAt', 'date'],
  );

  return docs.map((doc) {
    final data = doc.data();
    final tree =
        treeById[(data['treeId'] ?? '').toString().trim().toLowerCase()];
    final treeId = firstNonEmptyString([data['treeId']], fallback: 'Unknown');
    final farmId = firstNonEmptyString(
      [data['farmId']],
      fallback: tree == null ? '' : farmIdFromTree(tree),
    );
    final farmerName = firstNonEmptyString(
      [data['farmerName'], data['ownerName']],
      fallback: tree == null ? '' : farmerNameFromTree(tree),
    );
    final location = firstNonEmptyString(
      [data['location']],
      fallback: tree == null
          ? ''
          : firstNonEmptyString(
              [
                tree['location'],
                tree['address'],
                tree['plotNumber'],
                tree['plot'],
              ],
            ),
    );

    return AdminFarmActivity(
      type: AdminFarmActivityType.scan,
      treeId: treeId,
      farmId: farmId,
      farmerName: farmerName,
      location: location,
      title: 'Tree #$treeId scanned',
      subtitle: _activitySubtitle(farmId, farmerName),
      eventDate: _parseEventDate(
        data['savedAt'] ?? data['date'] ?? data['savedAtLocal'],
      ),
      dotColor: const Color(0xFF2D78D4),
      extraDetails: _cleanDetails({
        'RFID': firstNonEmptyString([data['rfid'], data['epc']]),
        'TID': firstNonEmptyString([data['tid']]),
        'HEALTH STATUS': firstNonEmptyString([data['healthstatus']]),
        'USER EMAIL': firstNonEmptyString([data['userEmail']]),
        'SOURCE': firstNonEmptyString([data['source']]),
      }),
    );
  }).toList(growable: false)
    ..sort((left, right) => right.eventDate.compareTo(left.eventDate));
}

List<AdminFarmActivity> _loadAdminIssues({
  required List<FarmManagerIssue> issues,
  required Map<String, Map<String, dynamic>> treeByDocId,
}) {
  return issues.map((issue) {
    final tree = treeByDocId[issue.treeDocId];
    final farmId = issue.farmId.isNotEmpty
        ? issue.farmId
        : (tree == null ? '' : farmIdFromTree(tree));
    final location = firstNonEmptyString(
      [
        tree == null ? '' : tree['location'],
        tree == null ? '' : tree['address'],
        tree == null ? '' : tree['plotNumber'],
        issue.farmLabel,
      ],
      fallback: issue.farmLabel,
    );

    return AdminFarmActivity(
      type: AdminFarmActivityType.issue,
      treeId: issue.treeId,
      farmId: farmId,
      farmerName: issue.ownerName,
      location: location,
      title: issue.title.isEmpty ? 'Issue reported' : issue.title,
      subtitle: _activitySubtitle(farmId, issue.ownerName),
      eventDate: issue.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      dotColor: const Color(0xFFE34A4A),
      extraDetails: _cleanDetails({
        'STATUS': issue.status,
        'SEVERITY': issue.severity,
        'HEALTH STATUS': issue.healthLabel,
        'NOTE': issue.note,
        'IMAGE': issue.hasImage ? 'Attached' : '',
      }),
    );
  }).toList(growable: false)
    ..sort((left, right) => right.eventDate.compareTo(left.eventDate));
}

Future<List<AdminFarmActivity>> _loadAdminHarvests({
  required FirebaseFirestore firestore,
  required Map<String, Map<String, dynamic>> treeById,
}) async {
  final docs = await _fetchRecentDocs(
    firestore.collection('harvest'),
    orderFields: const ['updatedAt', 'harvestDate', 'createdAt'],
  );

  return docs.map((doc) {
    final data = doc.data();
    final tree =
        treeById[(data['treeId'] ?? '').toString().trim().toLowerCase()];
    final farmId = firstNonEmptyString(
      [data['farmId']],
      fallback: tree == null ? '' : farmIdFromTree(tree),
    );
    final farmerName = firstNonEmptyString(
      [data['ownerName'], data['farmerName']],
      fallback: tree == null ? '' : farmerNameFromTree(tree),
    );
    final location = firstNonEmptyString(
      [data['location']],
      fallback: tree == null
          ? ''
          : firstNonEmptyString(
              [
                tree['location'],
                tree['address'],
                tree['plotNumber'],
                tree['plot'],
              ],
            ),
    );

    return AdminFarmActivity(
      type: AdminFarmActivityType.harvest,
      treeId: firstNonEmptyString([data['treeId']]),
      farmId: farmId,
      farmerName: farmerName,
      location: location,
      title: 'Harvest logged',
      subtitle: _activitySubtitle(farmId, farmerName),
      eventDate: _parseEventDate(
        data['updatedAt'] ??
            data['harvestDate'] ??
            data['date'] ??
            data['createdAt'],
      ),
      dotColor: const Color(0xFF3D9855),
      extraDetails: _cleanDetails({
        'QUANTITY': firstNonEmptyString([data['quantity']]),
        'UNIT': firstNonEmptyString([data['unit']]),
        'QUALITY': firstNonEmptyString(
          [data['qualityAssessment'], data['quality']],
        ),
        'SPECIES': firstNonEmptyString([data['species']]),
        'USER EMAIL': firstNonEmptyString([data['userEmail']]),
      }),
    );
  }).toList(growable: false)
    ..sort((left, right) => right.eventDate.compareTo(left.eventDate));
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchRecentDocs(
  CollectionReference<Map<String, dynamic>> collection, {
  List<String> orderFields = const [],
  int limit = 250,
}) async {
  for (final field in orderFields) {
    try {
      final snapshot =
          await collection.orderBy(field, descending: true).limit(limit).get();
      return snapshot.docs;
    } on FirebaseException {
      // Try the next ordering strategy.
    }
  }

  try {
    final snapshot = await collection.limit(limit).get();
    return snapshot.docs;
  } on FirebaseException {
    return const [];
  }
}

Map<String, String> _cleanDetails(Map<String, String> details) {
  final cleaned = <String, String>{};
  details.forEach((key, value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      cleaned[key] = trimmed;
    }
  });
  return cleaned;
}

Future<AdminFarmerProfile?> _loadFarmerProfile(
  FirebaseFirestore firestore,
  String farmerName,
) async {
  final normalizedName = farmerName.trim();
  if (normalizedName.isEmpty) {
    return null;
  }

  try {
    final snapshot = await firestore
        .collection('users')
        .where('name', isEqualTo: normalizedName)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      return AdminFarmerProfile(
        docId: doc.id,
        name: firstNonEmptyString([data['name']], fallback: normalizedName),
        email: firstNonEmptyString([data['email']]),
        phone: firstNonEmptyString([data['phone']]),
        role: firstNonEmptyString([data['role']], fallback: 'farmer'),
      );
    }
  } on FirebaseException {
    // Ignore exact-match query failures and fall back to a broader scan.
  }

  try {
    final snapshot = await firestore.collection('users').limit(200).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final currentName = (data['name'] ?? '').toString().trim();
      if (currentName.toLowerCase() == normalizedName.toLowerCase()) {
        return AdminFarmerProfile(
          docId: doc.id,
          name: currentName.isEmpty ? normalizedName : currentName,
          email: firstNonEmptyString([data['email']]),
          phone: firstNonEmptyString([data['phone']]),
          role: firstNonEmptyString([data['role']], fallback: 'farmer'),
        );
      }
    }
  } on FirebaseException {
    // Ignore fallback failures too.
  }

  return null;
}

String _formatCount(int value) {
  return NumberFormat.decimalPattern().format(value);
}

String _greetingName(UserModel? user) {
  final name = (user?.name ?? '').trim();
  return name.isEmpty ? 'Admin' : name;
}

String _activitySubtitle(String farmId, String farmerName) {
  final left = farmId.isEmpty ? 'Farm -' : 'Farm $farmId';
  final right = farmerName.isEmpty ? 'Unknown Farmer' : farmerName;
  return '$left - $right';
}

DateTime _parseEventDate(dynamic raw) {
  return parseDateTime(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String _timeAgo(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '-';
  }
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  return DateFormat('dd MMM').format(date);
}

String _fullDateTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '-';
  }
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

String _initials(String text) {
  final parts = text
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'AD';
  }
  return parts.map((part) => part[0].toUpperCase()).join();
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../auth/providers/auth_provider.dart';
import 'farm_manager_data.dart';

class FarmManagerDashboard extends ConsumerWidget {
  const FarmManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final name =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Manager';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FutureBuilder<FarmManagerScope>(
          future: loadFarmManagerScope(),
          builder: (context, scopeSnapshot) {
            if (scopeSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final scope = scopeSnapshot.data ??
                const FarmManagerScope(
                  managerUid: '',
                  managerEmail: '',
                  managerCode: '',
                  linkedFarmerIds: <String>{},
                  linkedFarmerEmails: <String>{},
                );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('farms').snapshots(),
              builder: (context, farmSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('trees')
                      .snapshots(),
                  builder: (context, treeSnapshot) {
                    if (treeSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (treeSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Unable to load dashboard data: ${treeSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final farmDocs = farmSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final treeDocs = treeSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final scopedTrees = buildScopedTrees(treeDocs, scope);
                    final farms = buildFarmSummaries(
                      farmDocs: farmDocs,
                      scopedTrees: scopedTrees,
                      scope: scope,
                    );

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collectionGroup('issues')
                          .snapshots(),
                      builder: (context, issueSnapshot) {
                        final issueDocs = issueSnapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        final issues = buildIssueSummaries(
                          issueDocs: issueDocs,
                          scopedTrees: scopedTrees,
                          scope: scope,
                        );

                        final healthyTrees = scopedTrees
                            .where(
                              (tree) =>
                                  healthLabel(tree['healthStatus']) ==
                                  'Healthy',
                            )
                            .length;
                        final moderateTrees = scopedTrees
                            .where(
                              (tree) =>
                                  healthLabel(tree['healthStatus']) ==
                                  'Needs Attention',
                            )
                            .length;
                        final criticalTrees = scopedTrees
                            .where(
                              (tree) => {
                                'At Risk',
                                'Critical',
                              }.contains(healthLabel(tree['healthStatus'])),
                            )
                            .length;
                        final criticalIssues = issues
                            .where((issue) => issue.severity == 'Critical')
                            .length;
                        final visibleAlerts = issues
                            .where((issue) => issue.severity != 'Resolved')
                            .take(3)
                            .toList(growable: false);

                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                children: [
                                  _WelcomeBanner(
                                    managerName: name,
                                    onBellTap: () {
                                      context.push(RoutePaths.activityLog);
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DashboardCountCard(
                                          title: 'Total Managed Farms',
                                          value: '${farms.length}',
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _DashboardCountCard(
                                          title: 'Total Trees',
                                          value: '${scopedTrees.length}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _HealthSummaryCard(
                                    healthyTrees: healthyTrees,
                                    moderateTrees: moderateTrees,
                                    criticalTrees: criticalTrees,
                                    totalTrees: scopedTrees.length,
                                  ),
                                  const SizedBox(height: 18),
                                  _IssueTrackerBanner(
                                    onTap: () {
                                      context
                                          .push(RoutePaths.farmManagerIssues);
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DashboardCountCard(
                                          title: 'Total Issues',
                                          value: '${issues.length}',
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _DashboardCountCard(
                                          title: 'Critical',
                                          value: '$criticalIssues',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Global Alerts Feed',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Recently',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (visibleAlerts.isEmpty)
                                    const _AlertTile(
                                      title: 'No Active Alerts',
                                      message:
                                          'Everything looks stable across managed farms.',
                                      backgroundColor: Color(0xFFE6F4EA),
                                      iconColor: Color(0xFF4CAF50),
                                    )
                                  else
                                    ...visibleAlerts.map(
                                      (issue) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _AlertTile(
                                          title: '${issue.severity} Alert',
                                          message: issue.note.isEmpty
                                              ? 'No message'
                                              : issue.note,
                                          backgroundColor:
                                              _alertBackground(issue.severity),
                                          iconColor: issueSeverityColor(
                                              issue.severity),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _DashboardBottomNav(
                              onHomeTap: () {
                                context.go(RoutePaths.farmManagerHome);
                              },
                              onFarmsTap: () {
                                context.push(RoutePaths.farmManagerFarms);
                              },
                              onScanTap: () {
                                context.push('/scan');
                              },
                              onAnalyticsTap: () {
                                context.push('/report');
                              },
                              onProfileTap: () {
                                context.push('/profile');
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Color _alertBackground(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFF5A1A1);
      case 'monitoring':
        return const Color(0xFFF5D6A3);
      case 'open':
        return const Color(0xFFF5B8B8);
      default:
        return const Color(0xFFF0E0E0);
    }
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.managerName,
    required this.onBellTap,
  });

  final String managerName;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2E8933),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFE3D5F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initialsFor(managerName),
                style: const TextStyle(
                  color: Color(0xFF2E8933),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Namaste,\nManager $managerName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          IconButton(
            onPressed: onBellTap,
            icon: const Icon(
              Icons.notifications,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCountCard extends StatelessWidget {
  const _DashboardCountCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA8D9A7),
            Color(0xFFB4E0B6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard({
    required this.healthyTrees,
    required this.moderateTrees,
    required this.criticalTrees,
    required this.totalTrees,
  });

  final int healthyTrees;
  final int moderateTrees;
  final int criticalTrees;
  final int totalTrees;

  @override
  Widget build(BuildContext context) {
    final goodRatio = totalTrees == 0 ? 0.0 : healthyTrees / totalTrees;
    final lowRatio = totalTrees == 0 ? 0.0 : moderateTrees / totalTrees;
    final highRatio = totalTrees == 0 ? 0.0 : criticalTrees / totalTrees;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Healthy Summary',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _LegendText(
                  color: const Color(0xFFFF4B3E),
                  text: 'Critical Health:$criticalTrees',
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _LegendText(
                    color: const Color(0xFF59C154),
                    text: 'Good Health:$healthyTrees',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 112,
                child: Column(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: 1,
                            strokeWidth: 11,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade300,
                            ),
                          ),
                          CircularProgressIndicator(
                            value: goodRatio.clamp(0.0, 1.0),
                            strokeWidth: 11,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF82D28A),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          Text(
                            '$healthyTrees',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Good Health',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _HealthBarRow(
                      label: 'Low',
                      value: lowRatio,
                      color: const Color(0xFFB99E95),
                    ),
                    const SizedBox(height: 16),
                    _HealthBarRow(
                      label: 'Good',
                      value: goodRatio,
                      color: const Color(0xFF84D38A),
                    ),
                    const SizedBox(height: 16),
                    _HealthBarRow(
                      label: 'High',
                      value: highRatio,
                      color: const Color(0xFFFF8A84),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendText extends StatelessWidget {
  const _LegendText({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthBarRow extends StatelessWidget {
  const _HealthBarRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 16,
              color: color,
              backgroundColor: color.withValues(alpha: 0.25),
            ),
          ),
        ),
      ],
    );
  }
}

class _IssueTrackerBanner extends StatelessWidget {
  const _IssueTrackerBanner({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF3D973B),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Row(
          children: [
            const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Issue Tracker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All Managed Farms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.iconColor,
  });

  final String title;
  final String message;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: iconColor,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.onHomeTap,
    required this.onFarmsTap,
    required this.onScanTap,
    required this.onAnalyticsTap,
    required this.onProfileTap,
  });

  final VoidCallback onHomeTap;
  final VoidCallback onFarmsTap;
  final VoidCallback onScanTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BottomNavItem(
              icon: Icons.home,
              label: 'Home',
              active: true,
              onTap: onHomeTap,
            ),
            _BottomNavItem(
              icon: Icons.agriculture_outlined,
              label: 'My Farms',
              onTap: onFarmsTap,
            ),
            GestureDetector(
              onTap: onScanTap,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF59C154),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            _BottomNavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              onTap: onAnalyticsTap,
            ),
            _BottomNavItem(
              icon: Icons.person,
              label: 'Profile',
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF59C154) : Colors.grey.shade500;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

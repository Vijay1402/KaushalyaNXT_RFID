import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';
import '../../farm_manager/presentation/farm_manager_providers.dart';
import '../../farm_manager/presentation/screens/analytics_screen.dart';
import '../../farm_manager/presentation/screens/issue_tracker_screen.dart';
import '../../farmer/profile/profile_screen.dart';
import 'admin_farm_management_screen.dart';
import 'admin_farm_overview_screen.dart';
import 'admin_user_management_screen.dart';

const _adminGreenDark = Color(0xFF116B3A);
const _adminGreenBright = Color(0xFF31C85B);
const _adminPanelColor = Color(0xFFF1F7F2);
const _adminTextDark = Color(0xFF202326);
const _adminTextMuted = Color(0xFF96A09A);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _screens = const [
    _AdminDashboardHome(),
    AdminFarmManagementScreen(),
    IssueTrackerScreen(),
    AnalyticsScreen(showBottomNavigation: false),
    ProfileScreen(showBackButton: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: _adminGreenDark,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.park_rounded),
            label: 'My Farm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardHome extends ConsumerWidget {
  const _AdminDashboardHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final usersAsync = ref.watch(usersSnapshotsProvider);
    final overviewAsync = ref.watch(globalFarmOverviewProvider);
    final activityAsync = ref.watch(adminFarmOverviewProvider);

    final error = _firstDashboardError(
      usersAsync: usersAsync,
      overviewAsync: overviewAsync,
      activityAsync: activityAsync,
    );
    final hasData =
        usersAsync.hasValue && overviewAsync.hasValue && activityAsync.hasValue;

    if (!hasData) {
      if (error != null) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: _AdminDashboardError(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(usersSnapshotsProvider);
                ref.invalidate(globalFarmOverviewProvider);
                ref.invalidate(adminFarmOverviewProvider);
              },
            ),
          ),
        );
      }

      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: _adminGreenDark),
          ),
        ),
      );
    }

    final dashboardData = _AdminDashboardData.fromSources(
      user: user,
      usersSnapshot: usersAsync.value!,
      overview: overviewAsync.value!,
      activityOverview: activityAsync.value!,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _HeaderBar(
              title: 'Namaste, ${dashboardData.greetingName}',
              onMenuTap: () => _showMenuSheet(context, ref),
              onNotificationsTap: () =>
                  _showAlertsSheet(context, dashboardData),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    _Panel(
                      child: _HealthScoreCard(data: dashboardData),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: _TrendCard(data: dashboardData),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: _UserStatsCard(
                        data: dashboardData,
                        onManageUsers: () => _openUserManagement(context),
                        onOpenActivity: () => _openActivityOverview(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: _ErrorLogsCard(
                        issues: dashboardData.errorLogs,
                        onOpenIssues: () => _openIssuesScreen(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: _SystemAlertsCard(
                        alerts: dashboardData.systemAlerts,
                        onOpenAnalytics: () => _openAnalyticsScreen(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenuSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('User Management'),
                subtitle: const Text('Add, edit, and remove users'),
                onTap: () {
                  Navigator.pop(context);
                  _openUserManagement(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Activity Overview'),
                subtitle: const Text('Open the admin activity overview'),
                onTap: () {
                  Navigator.pop(context);
                  _openActivityOverview(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Profile'),
                subtitle: const Text('Open your profile settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                subtitle: const Text('Sign out from admin dashboard'),
                onTap: () async {
                  Navigator.pop(context);
                  await _logout(context, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAlertsSheet(
    BuildContext context,
    _AdminDashboardData data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final alerts = [
          ...data.errorLogs.map(
            (issue) => _AlertItem(
              title: issue.label,
              subtitle: issue.statusLabel,
              color: issue.statusColor,
            ),
          ),
          ...data.systemAlerts.map(
            (alert) => _AlertItem(
              title: alert.label,
              subtitle: alert.detail,
              color: alert.color,
            ),
          ),
        ].take(6).toList(growable: false);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (alerts.isEmpty)
                  const Text(
                    'No active alerts right now.',
                    style: TextStyle(color: _adminTextMuted),
                  )
                else
                  ...alerts.map(
                    (alert) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3ECE4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: alert.color,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alert.subtitle,
                                  style: const TextStyle(
                                    color: _adminTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openIssuesScreen(context);
                    },
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Open Issues'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text(
              'Do you want to sign out from the admin dashboard?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) {
      context.go(RoutePaths.login);
    }
  }

  void _openUserManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminUserManagementScreen(showBackButton: true),
      ),
    );
  }

  void _openActivityOverview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminFarmOverviewScreen(),
      ),
    );
  }

  void _openIssuesScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IssueTrackerScreen(),
      ),
    );
  }

  void _openAnalyticsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AnalyticsScreen(showBottomNavigation: false),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.title,
    required this.onMenuTap,
    required this.onNotificationsTap,
  });

  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _adminGreenDark,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu_rounded),
            color: Colors.white,
            iconSize: 36,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: onNotificationsTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: _adminGreenBright,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _adminPanelColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.data});

  final _AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Score',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _adminTextDark,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                data.healthColor == Colors.red
                    ? Icons.warning_amber_rounded
                    : Icons.speed_rounded,
                color: data.healthColor,
                size: 42,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.healthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _adminTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${data.healthPercent}% healthy trees - '
                    '${data.openIssueCount} open issues',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _adminTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});

  final _AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Statistics',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _adminTextDark,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Yield Trends',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _adminTextDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Last 7 days',
          style: TextStyle(
            fontSize: 13,
            color: _adminTextMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              values: data.trendValues,
              labels: data.trendLabels,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserStatsCard extends StatelessWidget {
  const _UserStatsCard({
    required this.data,
    required this.onManageUsers,
    required this.onOpenActivity,
  });

  final _AdminDashboardData data;
  final VoidCallback onManageUsers;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final stats = <MapEntry<String, String>>[
      MapEntry('Total', data.totalUsers.toString()),
      MapEntry('Online', data.activeUsers.toString()),
      MapEntry('Signup', data.recentSignups.toString()),
      MapEntry('Growth', data.growthCount.toString()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Logs',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _adminTextDark,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var index = 0; index < stats.length; index++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index == stats.length - 1 ? 0 : 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5E8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        stats[index].key,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _adminTextDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats[index].value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _adminTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Role split: ${data.adminCount} admins - ${data.managerCount} '
          'managers - ${data.farmerCount} farmers',
          style: const TextStyle(
            fontSize: 12,
            color: _adminTextMuted,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onManageUsers,
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Manage Users'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _adminGreenDark,
                  side: const BorderSide(color: Color(0xFFB7D4BC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpenActivity,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Audit Log'),
                style: FilledButton.styleFrom(
                  backgroundColor: _adminGreenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorLogsCard extends StatelessWidget {
  const _ErrorLogsCard({
    required this.issues,
    required this.onOpenIssues,
  });

  final List<_ErrorLogItem> issues;
  final VoidCallback onOpenIssues;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Error Logs',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _adminTextDark,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenIssues,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (issues.isEmpty)
          const Text(
            'No pending error logs right now.',
            style: TextStyle(color: _adminTextMuted),
          )
        else
          ...issues.asMap().entries.map(
            (entry) {
              final issue = entry.value;
              return Column(
                children: [
                  _ListStatusRow(
                    title: issue.label,
                    trailingLabel: issue.statusLabel,
                    trailingColor: issue.statusColor,
                  ),
                  if (entry.key != issues.length - 1)
                    const Divider(height: 26, color: Color(0xFFD3D6DC)),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SystemAlertsCard extends StatelessWidget {
  const _SystemAlertsCard({
    required this.alerts,
    required this.onOpenAnalytics,
  });

  final List<_SystemAlertItem> alerts;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'System Alerts',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _adminTextDark,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenAnalytics,
              child: const Text('Analytics'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          const _ListIconRow(
            title: 'All systems stable',
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF31C85B),
          )
        else
          ...alerts.asMap().entries.map(
            (entry) {
              final alert = entry.value;
              return Column(
                children: [
                  _ListIconRow(
                    title: alert.label,
                    subtitle: alert.detail,
                    icon: Icons.warning_amber_rounded,
                    iconColor: alert.color,
                  ),
                  if (entry.key != alerts.length - 1)
                    const Divider(height: 26, color: Color(0xFFD3D6DC)),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ListStatusRow extends StatelessWidget {
  const _ListStatusRow({
    required this.title,
    required this.trailingLabel,
    required this.trailingColor,
  });

  final String title;
  final String trailingLabel;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              color: _adminTextDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          trailingLabel,
          style: TextStyle(
            fontSize: 15,
            color: trailingColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ListIconRow extends StatelessWidget {
  const _ListIconRow({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  color: _adminTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _adminTextMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: iconColor, size: 34),
      ],
    );
  }
}

class _AdminDashboardError extends StatelessWidget {
  const _AdminDashboardError({
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
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load admin dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _adminTextMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.labels,
  });

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 18.0;
    const bottomPadding = 42.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    if (chartRect.width <= 0 || chartRect.height <= 0 || values.isEmpty) {
      return;
    }

    final minValue =
        values.reduce((left, right) => left < right ? left : right);
    final maxValue =
        values.reduce((left, right) => left > right ? left : right);
    final normalizedMin = minValue == maxValue ? minValue - 1 : minValue;
    final normalizedMax = minValue == maxValue ? maxValue + 1 : maxValue;
    final span = normalizedMax - normalizedMin == 0
        ? 1.0
        : normalizedMax - normalizedMin;

    final stepX = values.length == 1
        ? chartRect.width
        : chartRect.width / (values.length - 1);

    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final ratio = (values[index] - normalizedMin) / span;
      points.add(
        Offset(
          chartRect.left + (stepX * index),
          chartRect.bottom - (ratio * chartRect.height),
        ),
      );
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final control = Offset((current.dx + next.dx) / 2, current.dy);
      final end = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      linePath.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }
    linePath.quadraticBezierTo(
      points.last.dx,
      points.last.dy,
      points.last.dx,
      points.last.dy,
    );

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x6631C85B),
            Color(0x1131C85B),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chartRect),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF31B956)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );

    const textStyle = TextStyle(
      color: _adminTextDark,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    for (var index = 0;
        index < labels.length && index < points.length;
        index++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[index], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          points[index].dx - (painter.width / 2),
          chartRect.bottom + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }
}

class _AdminDashboardData {
  _AdminDashboardData({
    required this.greetingName,
    required this.totalUsers,
    required this.activeUsers,
    required this.recentSignups,
    required this.growthCount,
    required this.adminCount,
    required this.managerCount,
    required this.farmerCount,
    required this.healthPercent,
    required this.healthLabel,
    required this.healthColor,
    required this.openIssueCount,
    required this.trendValues,
    required this.trendLabels,
    required this.errorLogs,
    required this.systemAlerts,
  });

  final String greetingName;
  final int totalUsers;
  final int activeUsers;
  final int recentSignups;
  final int growthCount;
  final int adminCount;
  final int managerCount;
  final int farmerCount;
  final int healthPercent;
  final String healthLabel;
  final Color healthColor;
  final int openIssueCount;
  final List<double> trendValues;
  final List<String> trendLabels;
  final List<_ErrorLogItem> errorLogs;
  final List<_SystemAlertItem> systemAlerts;

  factory _AdminDashboardData.fromSources({
    required UserModel? user,
    required QuerySnapshot<Map<String, dynamic>> usersSnapshot,
    required FarmManagerOverviewData overview,
    required AdminFarmOverviewData activityOverview,
  }) {
    var adminCount = 0;
    var managerCount = 0;
    var farmerCount = 0;
    var recentSignups = 0;
    var previousWeekSignups = 0;
    final now = DateTime.now();
    final activeUserKeys = <String>{};

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      switch (role) {
        case 'admin':
          adminCount++;
          break;
        case 'farm_manager':
          managerCount++;
          break;
        default:
          farmerCount++;
          break;
      }

      final createdAt = parseDateTime(
        data['createdAt'] ?? data['registeredAt'] ?? data['createdOn'],
      );
      if (createdAt != null) {
        final daysAgo = now.difference(createdAt).inDays;
        if (daysAgo >= 0 && daysAgo < 7) {
          recentSignups++;
        } else if (daysAgo >= 7 && daysAgo < 14) {
          previousWeekSignups++;
        }
      }

      final lastSeen = parseDateTime(data['lastSeen'] ?? data['updatedAt']);
      if (lastSeen != null &&
          now.difference(lastSeen) <= const Duration(hours: 24)) {
        activeUserKeys.add(doc.id);
      }
    }

    for (final activity in activityOverview.allActivities) {
      if (activity.eventDate.millisecondsSinceEpoch == 0) {
        continue;
      }
      if (now.difference(activity.eventDate) <= const Duration(hours: 24)) {
        final farmerName = activity.farmerName.trim().toLowerCase();
        if (farmerName.isNotEmpty) {
          activeUserKeys.add('name:$farmerName');
        }
      }
    }

    final totalTrees = overview.scopedTrees.length;
    final healthyTrees = overview.scopedTrees
        .where((tree) => _treeHealthLabel(tree['healthStatus']) == 'Healthy')
        .length;
    final healthPercent =
        totalTrees == 0 ? 100 : ((healthyTrees / totalTrees) * 100).round();

    final openIssues = overview.issues.where((issue) {
      final status = issue.status.trim().toLowerCase();
      return status != 'resolved' && status != 'closed';
    }).toList(growable: false);

    final errorLogs = openIssues
        .take(3)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _ErrorLogItem(
            label: 'ID ${(entry.key + 1).toString().padLeft(3, '0')} - '
                '${_trimText(entry.value.title)}',
            statusLabel: _issueStatusLabel(entry.value.status),
            statusColor: _issueStatusColor(entry.value.status),
          ),
        )
        .toList(growable: false);

    final alertFarms = overview.farms
        .where((farm) => farm.alertCount > 0)
        .toList(growable: false)
      ..sort((left, right) => right.alertCount.compareTo(left.alertCount));

    final systemAlerts = alertFarms.take(3).map((farm) {
      return _SystemAlertItem(
        label: _trimText(farm.name),
        detail: '${farm.alertCount} alert(s) - ${farm.location}',
        color: farm.alertCount >= 5 ? Colors.red : Colors.orange,
      );
    }).toList(growable: false);

    final healthLabelText = healthPercent >= 85 && openIssues.isEmpty
        ? 'System Running Smoothly'
        : healthPercent >= 70
            ? 'Minor Alerts Need Review'
            : 'Admin Attention Required';

    final resolvedGreeting = (user?.name ?? '').trim();
    final growthCount = recentSignups > previousWeekSignups
        ? recentSignups - previousWeekSignups
        : 0;

    return _AdminDashboardData(
      greetingName: resolvedGreeting.isEmpty ? 'Admin' : resolvedGreeting,
      totalUsers: usersSnapshot.docs.length,
      activeUsers: activeUserKeys.length,
      recentSignups: recentSignups,
      growthCount: growthCount,
      adminCount: adminCount,
      managerCount: managerCount,
      farmerCount: farmerCount,
      healthPercent: healthPercent,
      healthLabel: healthLabelText,
      healthColor: healthPercent >= 85 && openIssues.isEmpty
          ? const Color(0xFF31B956)
          : healthPercent >= 70
              ? Colors.orange
              : Colors.red,
      openIssueCount: openIssues.length,
      trendValues: _buildTrendValues(
        trees: overview.scopedTrees,
        activities: activityOverview.allActivities,
      ),
      trendLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      errorLogs: errorLogs,
      systemAlerts: systemAlerts,
    );
  }
}

class _ErrorLogItem {
  const _ErrorLogItem({
    required this.label,
    required this.statusLabel,
    required this.statusColor,
  });

  final String label;
  final String statusLabel;
  final Color statusColor;
}

class _SystemAlertItem {
  const _SystemAlertItem({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}

class _AlertItem {
  const _AlertItem({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;
}

Object? _firstDashboardError({
  required AsyncValue<QuerySnapshot<Map<String, dynamic>>> usersAsync,
  required AsyncValue<FarmManagerOverviewData> overviewAsync,
  required AsyncValue<AdminFarmOverviewData> activityAsync,
}) {
  if (usersAsync.hasError) {
    return usersAsync.error;
  }
  if (overviewAsync.hasError) {
    return overviewAsync.error;
  }
  if (activityAsync.hasError) {
    return activityAsync.error;
  }
  return null;
}

List<double> _buildTrendValues({
  required List<Map<String, dynamic>> trees,
  required List<AdminFarmActivity> activities,
}) {
  final now = DateTime.now();
  final values = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);

  for (final tree in trees) {
    final lastUpdated = parseDateTime(
      tree['lastinspectiondate'] ??
          tree['lastInspectionDate'] ??
          tree['updatedAt'] ??
          tree['createdAt'],
    );
    if (lastUpdated == null) {
      continue;
    }
    final daysAgo = now.difference(lastUpdated).inDays;
    if (daysAgo < 0 || daysAgo >= 7) {
      continue;
    }
    final index = 6 - daysAgo;
    final yieldValue = asDouble(tree['lastYieldKg'] ?? tree['yieldKg']);
    values[index] += yieldValue;
    if (yieldValue > 0) {
      counts[index]++;
    }
  }

  var hasYieldData = false;
  for (var index = 0; index < values.length; index++) {
    if (counts[index] > 0) {
      values[index] = values[index] / counts[index];
      hasYieldData = true;
    }
  }

  if (!hasYieldData) {
    for (final activity in activities) {
      final daysAgo = now.difference(activity.eventDate).inDays;
      if (daysAgo < 0 || daysAgo >= 7) {
        continue;
      }
      values[6 - daysAgo] += 1;
    }
  }

  if (values.every((value) => value == 0)) {
    final base = trees.isEmpty ? 1.0 : trees.length.toDouble();
    return [
      base * 0.72,
      base * 0.58,
      base * 0.96,
      base * 0.79,
      base * 0.85,
      base * 1.08,
      base * 0.96,
    ];
  }

  return values;
}

String _trimText(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return 'Issue';
  }
  if (text.length <= 22) {
    return text;
  }
  return '${text.substring(0, 22)}...';
}

String _issueStatusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'resolved' || normalized == 'closed') {
    return 'Resolved';
  }
  if (normalized == 'in progress' || normalized == 'in_progress') {
    return 'In Progress';
  }
  return 'Pending';
}

Color _issueStatusColor(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'resolved' || normalized == 'closed') {
    return const Color(0xFF31B956);
  }
  if (normalized == 'in progress' || normalized == 'in_progress') {
    return Colors.blue;
  }
  return const Color(0xFFF5A000);
}

String _treeHealthLabel(dynamic rawStatus) {
  return healthLabel(rawStatus);
}

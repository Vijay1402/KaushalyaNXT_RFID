import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';

class AgricultureOfficerDashboardScreen extends ConsumerWidget {
  const AgricultureOfficerDashboardScreen({super.key});

  static const _accentColor = Color(0xFF15803D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Agriculture Officer';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: SafeArea(
        child: ListView(
          padding: ResponsiveLayout.pageInsets(
            context,
            top: 18,
            bottom: 28,
            compact: 16,
            regular: 20,
            wide: 28,
          ),
          children: [
            _AgricultureOfficerHeader(
              name: name,
              onProfileTap: () => context.push('/profile'),
              onLogoutTap: () => _logout(context, ref),
            ),
            const SizedBox(height: 18),
            const ResponsiveWrapGrid(
              minChildWidth: 180,
              maxColumns: 2,
              spacing: 14,
              runSpacing: 14,
              children: [
                _AgricultureOfficerDashboardCard(
                  icon: Icons.verified_outlined,
                  title: 'Field Verification',
                  subtitle:
                      'Review farm visits, crop status, and observations.',
                ),
                _AgricultureOfficerDashboardCard(
                  icon: Icons.eco_outlined,
                  title: 'Crop Advisory',
                  subtitle:
                      'Prepare guidance for farmers and local farm teams.',
                ),
                _AgricultureOfficerDashboardCard(
                  icon: Icons.fact_check_outlined,
                  title: 'Inspection Reports',
                  subtitle:
                      'Monitor pending reports and completed inspections.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _AgricultureOfficerActionPanel(),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) {
      context.go(RoutePaths.login);
    }
  }
}

class _AgricultureOfficerHeader extends StatelessWidget {
  const _AgricultureOfficerHeader({
    required this.name,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  final String name;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AgricultureOfficerDashboardScreen._accentColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Agriculture Officer Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onProfileTap,
                icon: const Icon(Icons.person_outline_rounded),
                color: Colors.white,
                tooltip: 'Profile',
              ),
              IconButton(
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgricultureOfficerDashboardCard extends StatelessWidget {
  const _AgricultureOfficerDashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AgricultureOfficerDashboardScreen._accentColor,
            size: 30,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2933),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF68736A),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgricultureOfficerActionPanel extends StatelessWidget {
  const _AgricultureOfficerActionPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E2)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AgricultureOfficerDashboardScreen._accentColor,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Agriculture officer tools can be added here as the workflow grows.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

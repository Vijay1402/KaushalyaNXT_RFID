import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';

class KvkDashboardScreen extends ConsumerWidget {
  const KvkDashboardScreen({super.key});

  static const _accentColor = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'KVK User';

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
            _KvkHeader(
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
                _KvkDashboardCard(
                  icon: Icons.school_outlined,
                  title: 'Farmer Training',
                  subtitle:
                      'Plan advisory, training, and field support activities.',
                ),
                _KvkDashboardCard(
                  icon: Icons.science_outlined,
                  title: 'Demo Plots',
                  subtitle:
                      'Track demonstrations and technology transfer work.',
                ),
                _KvkDashboardCard(
                  icon: Icons.assignment_outlined,
                  title: 'Reports',
                  subtitle:
                      'Review field updates and farmer outreach summaries.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _KvkActionPanel(),
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

class _KvkHeader extends StatelessWidget {
  const _KvkHeader({
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
        color: KvkDashboardScreen._accentColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KVK Dashboard',
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

class _KvkDashboardCard extends StatelessWidget {
  const _KvkDashboardCard({
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
          Icon(icon, color: KvkDashboardScreen._accentColor, size: 30),
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

class _KvkActionPanel extends StatelessWidget {
  const _KvkActionPanel();

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
          Icon(Icons.info_outline_rounded,
              color: KvkDashboardScreen._accentColor),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'KVK tools can be added here as the workflow grows.',
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

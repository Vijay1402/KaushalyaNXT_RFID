import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/local_storage_viewer_screen.dart';
import '../../features/farmer/dashboard/farmer_dashboard.dart';
import '../../features/farmer/dashboard/activity_log_screen.dart';
import '../../features/farm_manager/presentation/farm_manager_dashboard.dart';
import '../../features/farmer/my_trees/my_trees_screen.dart';
import '../../features/farmer/profile/profile_screen.dart';
import '../../features/rfid/rfid_scan_screen.dart';
import '../../features/farmer/reports/reports_screen.dart';
import '../../features/farmer/tree_details/tree_detail_screen.dart';
import '../../features/auth/presentation/notification_settings_screen.dart';
import 'package:kaushalyanxt_rfid/features/auth/presentation/faq_screen.dart';
import 'package:kaushalyanxt_rfid/features/auth/presentation/support_screen.dart';
import '../../features/farm_manager/presentation/screens/farm_list_screen.dart';
import '../../features/farm_manager/presentation/screens/farm_detail_screen.dart';
import '../../features/farm_manager/presentation/screens/issue_tracker_screen.dart';

GoRouter createRouter(ProviderRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',

    /// ✅ ERROR SCREEN
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      );
    },

    /// ✅ REDIRECT LOGIC (FIXED)
    redirect: (context, state) {
      final loggedIn = authState.user != null;
      final initialized = authState.isInitialized;
      final location = state.matchedLocation;

      if (!initialized && location != '/') return '/';

      if (location == '/') {
        return loggedIn ? '/farm-manager/home' : '/login';
      }

      if (!loggedIn &&
          location != '/login' &&
          location != '/register' &&
          location != '/forgot-password') {
        return '/login';
      }

      if (loggedIn &&
          (location == '/login' ||
              location == '/register' ||
              location == '/forgot-password')) {
        return '/farm-manager/home';
      }

      return null;
    },

    routes: [

      /// SPLASH
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      /// AUTH
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      /// DASHBOARDS
      GoRoute(
        path: '/farmer/home',
        builder: (context, state) => const FarmerDashboard(),
      ),

      GoRoute(
        path: '/farm-manager/home',
        builder: (context, state) => const FarmManagerDashboard(),
      ),

      GoRoute(
        path: '/activity-log',
        builder: (context, state) => const ActivityLogScreen(),
      ),

      /// FEATURES
      GoRoute(
        path: '/my-trees',
        builder: (context, state) => const MyTreesScreen(),
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      GoRoute(
        path: '/local-storage',
        builder: (context, state) => const LocalStorageViewerScreen(),
      ),

      GoRoute(
        path: '/faq',
        builder: (context, state) => const FAQScreen(),
      ),

      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),

      GoRoute(
        path: '/scan',
        builder: (context, state) => const RFIDScanScreen(),
      ),

      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportsScreen(),
      ),

      /// ✅ FARM LIST (WORKING)
      GoRoute(
        path: '/farms',
        builder: (context, state) => const FarmListScreen(),
      ),
      GoRoute(
        path: '/farm-details',
        builder: (context, state) {
          final farmId = state.extra as String?;
          return FarmManagerDetails(farmId: farmId);
        },
      ),
      GoRoute(
        path: '/issue-tracker',
        builder: (context, state) => const IssueTrackerScreen(),
      ),
      /// ✅ TREE DETAILS (SAFE)
      GoRoute(
        path: '/tree-details',
        builder: (context, state) {
          final id = state.extra as String? ?? "";
          final source =
              state.uri.queryParameters['source'] ?? 'myTrees';

          return TreeDetailScreen(
            treeId: id,
            source: source,
          );
        },
      ),
    ],
  );
}
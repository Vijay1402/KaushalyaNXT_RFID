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
import 'route_paths.dart';
import '../../features/farm_manager/presentation/screens/farm_list_screen.dart';

GoRouter createRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final loggedIn = authState.user != null;
      final initialized = authState.isInitialized;
      final location = state.matchedLocation;
      final homeRoute = RoutePaths.homeForRole(authState.user?.role);

      final isSplash = location == RoutePaths.splash;
      final isLogin = location == RoutePaths.login;
      final isRegister = location == RoutePaths.register;
      final isForgotPassword = location == RoutePaths.forgotPassword;

      if (!initialized) {
        return isSplash ? null : RoutePaths.splash;
      }

      if (isSplash) {
        return loggedIn ? homeRoute : RoutePaths.login;
      }

      /// ❌ NOT LOGGED IN → allow only auth screens
      if (!loggedIn && !isLogin && !isRegister && !isForgotPassword) {
        return RoutePaths.login;
      }

      /// ❌ LOGGED IN → prevent going back to auth screens
      if (loggedIn && (isLogin || isRegister || isForgotPassword)) {
        return homeRoute;
      }

      if (loggedIn &&
          location == RoutePaths.farmerHome &&
          homeRoute != RoutePaths.farmerHome) {
        return homeRoute;
      }

      if (loggedIn &&
          location == RoutePaths.farmManagerHome &&
          homeRoute != RoutePaths.farmManagerHome) {
        return homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      /// LOGIN
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),

      /// REGISTER
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      /// FORGOT PASSWORD ✅
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      /// DASHBOARD
      GoRoute(
        path: RoutePaths.farmerHome,
        builder: (context, state) => const FarmerDashboard(),
      ),

      GoRoute(
        path: RoutePaths.farmManagerHome,
        builder: (context, state) => const FarmManagerDashboard(),
      ),

      GoRoute(
        path: RoutePaths.activityLog,
        builder: (context, state) => const ActivityLogScreen(),
      ),

      /// MY TREES
      GoRoute(
        name: 'myTrees',
        path: '/my-trees',
        builder: (context, state) => const MyTreesScreen(),
      ),

      /// PROFILE
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
      ), // SCAN

      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const RFIDScanScreen(),
      ),

      /// REPORT
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/farms',
        builder: (context, state) => const FarmListScreen(),
      ),
      /// TREE DETAILS
      GoRoute(
        name: 'treeDetails',
        path: '/treedetails',
        builder: (context, state) {
          final id = state.extra as String;
          final source = state.uri.queryParameters['source'] ?? 'myTrees';
          return TreeDetailScreen(
            treeId: id,
            source: source,
          );
        },
      ),
    ],
  );
}

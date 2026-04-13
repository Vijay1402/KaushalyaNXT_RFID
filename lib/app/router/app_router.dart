import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/farmer/dashboard/farmer_dashboard.dart';
import '../../features/farmer/my_trees/my_trees_screen.dart';
import '../../features/farmer/profile/profile_screen.dart';
import '../../features/rfid/rfid_scan_screen.dart';
import '../../features/farmer/reports/reports_screen.dart';
import '../../features/farmer/tree_details/tree_detail_screen.dart';
import '../../features/auth/presentation/notification_settings_screen.dart';
import 'package:kaushalyanxt_rfid/features/auth/presentation/faq_screen.dart';
import 'package:kaushalyanxt_rfid/features/auth/presentation/support_screen.dart';
import 'route_paths.dart';

GoRouter createRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,

    redirect: (context, state) {
      final loggedIn = authState.user != null;
      final location = state.matchedLocation;

      final isLogin = location == RoutePaths.login;
      final isRegister = location == RoutePaths.register;
      final isForgotPassword =
          location == RoutePaths.forgotPassword;

      /// ❌ NOT LOGGED IN → allow only auth screens
      if (!loggedIn &&
          !isLogin &&
          !isRegister &&
          !isForgotPassword) {
        return RoutePaths.login;
      }

      /// ❌ LOGGED IN → prevent going back to auth screens
      if (loggedIn &&
          (isLogin || isRegister || isForgotPassword)) {
        return RoutePaths.farmerHome;
      }

      return null;
    },

    routes: [
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
        builder: (context, state) =>
            const ForgotPasswordScreen(),
      ),

      /// DASHBOARD
      GoRoute(
        path: RoutePaths.farmerHome,
        builder: (context, state) => const FarmerDashboard(),
      ),

      /// MY TREES
      GoRoute(
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
        builder: (context, state) =>const NotificationSettingsScreen(),
      ),
      
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FAQScreen(),
      ),// SCAN

      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/scan',  
        builder: (context, state) =>
            const RFIDScanScreen(),
      ),

      /// REPORT
      GoRoute(
        path: '/report',
        builder: (context, state) =>
            const ReportsScreen(),
      ),

      /// TREE DETAILS
     GoRoute(
        name: 'treeDetails',
        path: '/treeDetails',
        builder: (context, state) {
          final treeId = state.extra as String;

          return TreeDetailScreen(treeId: treeId);
        },
      ),
    
    ],
  );
}
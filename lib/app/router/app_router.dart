import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/farmer/dashboard/farmer_dashboard.dart';
import '../../features/farmer/my_trees/my_trees_screen.dart';
import '../../features/farmer/profile/profile_screen.dart';
import '../../features/rfid/rfid_scan_screen.dart';
import '../../features/farmer/reports/reports_screen.dart';
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

      // ❌ NOT LOGGED IN → force login
      if (!loggedIn && !isLogin && !isRegister) {
        return RoutePaths.login;
      }

      // ❌ LOGGED IN → prevent going back to login
      if (loggedIn && (isLogin || isRegister)) {
        return RoutePaths.farmerHome;
      }

      // ✅ ALLOW ALL OTHER ROUTES
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

      /// 🔥 FIXED PROFILE (LOWERCASE)
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      /// 🔥 SCAN
      GoRoute(
        path: '/scan',
        builder: (context, state) => const RFIDScanScreen(),
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
  );
}
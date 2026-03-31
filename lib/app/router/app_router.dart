import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/farmer/dashboard/farmer_dashboard.dart';
import '../../features/farmer/my_trees/my_trees_screen.dart';
import 'route_paths.dart';

GoRouter createRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,

    /// 🔥 FIXED REDIRECT LOGIC
    redirect: (context, state) {
      final loggedIn = authState.user != null;
      final location = state.matchedLocation;
      final isLogin = state.matchedLocation == RoutePaths.login;
      final isRegister = state.matchedLocation == RoutePaths.register;

      // ✅ Allow login & register when NOT logged in
      if (loggedIn && state.matchedLocation == '/my-trees') {
        return null; // allow navigation
      }
      if (!loggedIn && !isLogin && !isRegister) {
        return RoutePaths.login;
      }

      // ✅ If logged in → go to farmer dashboard
      if (loggedIn && authState.user!.role == "farmer") {
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

      /// FARMER DASHBOARD
      GoRoute(
        path: RoutePaths.farmerHome,
        builder: (context, state) => const FarmerDashboard(),
      ),
      GoRoute(
        path: '/my-trees',
        builder: (context, state) => const MyTreesScreen(),
      ),
    ],
  );
}
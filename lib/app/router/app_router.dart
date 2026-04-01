import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// AUTH
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';

// DASHBOARD
import '../../features/farmer/dashboard/farmer_dashboard.dart';

// 🌳 TREES + DETAILS
import '../../features/admin/trees_page.dart';
import '../../features/admin/tree_details_page.dart';

import 'route_paths.dart';

GoRouter createRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final loggedIn = authState.user != null;

      final isLogin = state.matchedLocation == RoutePaths.login;
      final isRegister = state.matchedLocation == RoutePaths.register;

      // ❌ NOT LOGGED IN
      if (!loggedIn && !isLogin && !isRegister) {
        return RoutePaths.login;
      }

      // ✅ LOGGED IN → BLOCK LOGIN/REGISTER
      if (loggedIn && (isLogin || isRegister)) {
        return '/trees';
      }

      return null;
    },

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Text(
            "Route not found:\n${state.uri}",
            textAlign: TextAlign.center,
          ),
        ),
      );
    },

    routes: [
      // 🔐 LOGIN
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // 📝 REGISTER
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // 👨‍🌾 DASHBOARD
      GoRoute(
        path: RoutePaths.farmerHome,
        builder: (context, state) => const FarmerDashboard(),
      ),

      // 🌳 TREES
      GoRoute(
        path: '/trees',
        name: 'trees',
        builder: (context, state) => const TreesPage(),
      ),

      // 🌳 TREE DETAILS (🔥 FIXED)
      GoRoute(
        path: '/tree-details',
        name: 'treeDetails',
        builder: (context, state) {
          final extra = state.extra;

          // ✅ MUST BE STRING (docId)
          if (extra is String) {
            return TreeDetailsPage(docId: extra);
          }

          return const Scaffold(
            body: Center(child: Text("Invalid Tree ID")),
          );
        },
      ),
    ],
  );
}
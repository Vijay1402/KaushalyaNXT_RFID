import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ IMPORT PAGES
import 'package:kaushalyanxt_rfid/features/admin/trees_page.dart';
import 'package:kaushalyanxt_rfid/features/admin/tree_details_page.dart';
import 'package:kaushalyanxt_rfid/features/admin/user_details_page.dart';
import 'package:kaushalyanxt_rfid/features/admin/event_details_page.dart'; // 🔥 ADD THIS

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/trees',
    debugLogDiagnostics: true,

    // ✅ ERROR PAGE
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
      /// 🌳 TREES PAGE
      GoRoute(
        path: '/trees',
        name: 'trees',
        builder: (context, state) => const TreesPage(),
      ),

      /// 🌳 TREE DETAILS PAGE
      GoRoute(
        path: '/tree-details',
        name: 'treeDetails',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is String && extra.isNotEmpty) {
            return TreeDetailsPage(docId: extra);
          }

          return const Scaffold(
            body: Center(child: Text("Invalid or missing Tree ID")),
          );
        },
      ),

      /// 👤 USER DETAILS PAGE
      GoRoute(
        path: '/user-details',
        name: 'userDetails',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is String && extra.isNotEmpty) {
            return UserDetailsPage(userId: extra);
          }

          return const Scaffold(
            body: Center(child: Text("Invalid or missing User ID")),
          );
        },
      ),

      /// 📅 EVENT DETAILS PAGE (🔥 NEW FIX)
      GoRoute(
        path: '/event-details',
        name: 'eventDetails',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is String && extra.isNotEmpty) {
            return EventDetailsPage(eventId: extra);
          }

          return const Scaffold(
            body: Center(child: Text("Invalid or missing Event ID")),
          );
        },
      ),
    ],
  );
});
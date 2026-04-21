import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/router/router_provider.dart';
import 'core/services/offline_sync_service.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  /// ✅ SAFE async call
  Future.microtask(() => _bootstrapApp(container));
}

Future<void> _bootstrapApp(ProviderContainer container) async {
  final connectivityResults = await Connectivity().checkConnectivity();

  final isOnline = connectivityResults != ConnectivityResult.none;

  if (!isOnline) {
    await FirebaseFirestore.instance.disableNetwork();
  } else {
    await FirebaseFirestore.instance.enableNetwork();
  }

  await container.read(authStateProvider.notifier).checkLogin();

  if (isOnline) {
    await OfflineSyncService().syncPendingTreeWrites();
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    /// ✅ FIXED CONNECTIVITY LISTENER
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(
      (results) async {
        final isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;

        if (isOnline) {
          await FirebaseFirestore.instance.enableNetwork();
          await _offlineSyncService.syncPendingTreeWrites();
        } else {
          await FirebaseFirestore.instance.disableNetwork();
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
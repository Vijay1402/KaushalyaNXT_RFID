import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/router/router_provider.dart';
import 'core/providers/firebase_providers.dart';
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

  unawaited(_bootstrapApp(container));
}

Future<void> _bootstrapApp(ProviderContainer container) async {
  final firestore = container.read(firestoreProvider);
  final initialConnectivity = await Connectivity().checkConnectivity();
  if (initialConnectivity == ConnectivityResult.none) {
    await firestore.disableNetwork();
  } else {
    await firestore.enableNetwork();
  }

  await container.read(authStateProvider.notifier).checkLogin();

  if (initialConnectivity != ConnectivityResult.none) {
    await container.read(offlineSyncServiceProvider).syncPendingTreeWrites();
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (result) async {
        final firestore = ref.read(firestoreProvider);
        final offlineSyncService = ref.read(offlineSyncServiceProvider);
        if (result != ConnectivityResult.none) {
          await firestore.enableNetwork();
          await offlineSyncService.syncPendingTreeWrites();
        } else {
          await firestore.disableNetwork();
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

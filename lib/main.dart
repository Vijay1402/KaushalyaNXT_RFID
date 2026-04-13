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
  final initialConnectivity = await Connectivity().checkConnectivity();
  if (initialConnectivity == ConnectivityResult.none) {
    await FirebaseFirestore.instance.disableNetwork();
  } else {
    await FirebaseFirestore.instance.enableNetwork();
  }

  /// 🔥 AUTO LOGIN
  await container.read(authStateProvider.notifier).checkLogin();
  await OfflineSyncService().syncPendingTreeWrites();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (result) async {
        if (result != ConnectivityResult.none) {
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

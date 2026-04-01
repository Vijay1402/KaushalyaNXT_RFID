import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ REQUIRED
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app/router/router_provider.dart';
import 'add_tree.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    // ✅ Anonymous login (only if not already logged in)
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    final container = ProviderContainer();

    /// 🔥 AUTO LOGIN
  

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
  } catch (e) {
    // ❌ If Firebase fails, app should not silently crash
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Firebase initialization failed")),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
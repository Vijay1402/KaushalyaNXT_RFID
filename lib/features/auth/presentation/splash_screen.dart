import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  void checkUser() async {
    await ref.read(authStateProvider.notifier).checkLogin();

    final user = ref.read(authStateProvider).user;

    if (!mounted) return;

    if (user != null) {
      if (user.role == 'farmer') {
        context.go('/farmer');
      } else {
        context.go('/kvk');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// ✅ Global GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(ref);

  /// Optional: Dispose router when provider is destroyed
  ref.onDispose(() {
    router.dispose();
  });

  return router;
});
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});
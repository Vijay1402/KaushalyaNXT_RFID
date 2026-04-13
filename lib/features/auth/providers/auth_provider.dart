import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADD THIS
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../data/models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;

  AuthState({this.user, this.isLoading = false});

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final authServiceProvider = Provider((ref) => AuthService());
final localCacheServiceProvider = Provider((ref) => LocalCacheService());

final authStateProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  /// AUTO LOGIN
  Future<void> checkLogin() async {
    final authService = ref.read(authServiceProvider);
    final cache = ref.read(localCacheServiceProvider);
    final firebaseUser = authService.getCurrentUser();

    if (firebaseUser != null) {
      try {
        final doc = await authService.firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final user = UserModel(
            name: data['name'],
            email: data['email'],
            role: data['role'],
            phone: (data['phone'] ?? '').toString(),
          );
          await cache.saveUser(user);
          state = AuthState(user: user);
          return;
        }
      } catch (_) {
        final cachedUser = await cache.getUser();
        if (cachedUser != null) {
          state = AuthState(user: cachedUser);
          return;
        }
      }
    }

    final cachedUser = await cache.getUser();
    if (cachedUser != null) {
      state = AuthState(user: cachedUser);
    }
  }

  /// LOGIN
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await ref.read(authServiceProvider).login(email, password);
      await ref.read(localCacheServiceProvider).saveUser(user);

      state = AuthState(user: user, isLoading: false);
    } on FirebaseAuthException catch (e) {
      // ✅ ADD THIS BLOCK
      state = state.copyWith(isLoading: false);
      throw e; // ✅ pass exact firebase error
    } catch (e) {
      // ✅ MODIFY ONLY THIS PART
      state = state.copyWith(isLoading: false);

      /// 🔥 fallback mapping (if service didn't throw properly)
      if (e.toString().contains("user-not-found")) {
        throw FirebaseAuthException(code: "user-not-found");
      } else if (e.toString().contains("wrong-password")) {
        throw FirebaseAuthException(code: "wrong-password");
      } else if (e.toString().contains("invalid-email")) {
        throw FirebaseAuthException(code: "invalid-email");
      } else if (e.toString().contains("invalid-credential")) {
        throw FirebaseAuthException(code: "invalid-credential");
      }

      rethrow;
    }
  }

  /// REGISTER
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await ref.read(authServiceProvider).register(
            name: name,
            email: email,
            password: password,
            role: role,
            phone: phone,
          );
      await ref.read(localCacheServiceProvider).saveUser(user);

      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// GOOGLE LOGIN
  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      await ref.read(localCacheServiceProvider).saveUser(user);

      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await ref.read(authServiceProvider).updateProfile(
            name: name,
            email: email,
            phone: phone,
          );
      await ref.read(localCacheServiceProvider).saveUser(user);
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> sendPasswordReset() async {
    final email = state.user?.email.trim() ?? '';
    if (email.isEmpty) {
      throw Exception('No email found for this account');
    }

    await ref.read(authServiceProvider).sendPasswordResetEmail(email);
  }

  /// LOGOUT
  Future<void> logout() async {
    final currentUser = ref.read(authServiceProvider).getCurrentUser();
    await ref.read(authServiceProvider).logout();
    await ref.read(localCacheServiceProvider).clearUser();
    if (currentUser != null) {
      await ref.read(localCacheServiceProvider).clearTrees(currentUser.uid);
      await ref
          .read(localCacheServiceProvider)
          .clearWrittenTags(currentUser.uid);
      await ref
          .read(localCacheServiceProvider)
          .clearPendingTreeSyncs(currentUser.uid);
      await ref
          .read(localCacheServiceProvider)
          .clearPendingIssues(currentUser.uid);
      await ref
          .read(localCacheServiceProvider)
          .clearIssueHistory(currentUser.uid);
    }
    state = AuthState();
  }
}

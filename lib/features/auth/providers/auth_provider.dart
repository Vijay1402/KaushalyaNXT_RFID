import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADD THIS
import '../../../core/services/auth_service.dart';
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

final authStateProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  /// AUTO LOGIN
  Future<void> checkLogin() async {
    final authService = ref.read(authServiceProvider);
    final firebaseUser = authService.getCurrentUser();

    if (firebaseUser != null) {
      final doc = await authService.firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        state = AuthState(
          user: UserModel(
            name: data['name'],
            email: data['email'],
            role: data['role'],
          ),
        );
      }
    }
  }

  /// LOGIN
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final user =
          await ref.read(authServiceProvider).login(email, password);

      state = AuthState(user: user, isLoading: false);
    } on FirebaseAuthException { // ✅ ADD THIS BLOCK
      state = state.copyWith(isLoading: false);
      rethrow; // ✅ pass exact firebase error
    } catch (e) { // ✅ MODIFY ONLY THIS PART
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
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final user =
          await ref.read(authServiceProvider).register(
        name: name,
        email: email,
        password: password,
        role: role,
      );

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
      final user =
          await ref.read(authServiceProvider).signInWithGoogle();

      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// LOGOUT
  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = AuthState();
  }
}
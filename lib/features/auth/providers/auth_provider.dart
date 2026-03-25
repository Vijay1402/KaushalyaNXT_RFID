import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// SERVICE PROVIDER
final authServiceProvider = Provider((ref) => AuthService());

// STATE PROVIDER
final authStateProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

// CONTROLLER
class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await ref.read(authServiceProvider).login(email, password);
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState();
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true);

    final user = await ref.read(authServiceProvider).register(
          name: name,
          email: email,
          password: password,
          role: role,
        );

    state = AuthState(user: user);
  }

  void logout() {
    state = AuthState();
  }
}
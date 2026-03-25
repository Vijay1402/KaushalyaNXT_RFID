import '../../data/models/user_model.dart';

class AuthService {
  /// LOGIN METHOD
  Future<UserModel> login(String email, String password) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Fake validation
    if (email == "test@test.com" && password == "123456") {
      return UserModel(
        name: "Test User",
        email: email,
        role: "farmer", // change role if needed
      );
    } else {
      throw Exception("Invalid email or password");
    }
  }

  /// REGISTER METHOD
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Return created user (no real storage)
    return UserModel(
      name: name,
      email: email,
      role: role, // dynamic role (farmer / kvk)
    );
  }
}
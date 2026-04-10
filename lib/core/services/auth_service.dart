import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// 🔐 CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 🔐 LOGIN (FIXED + SAFE)
  Future<UserModel> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("Login failed");

      final doc = await firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        throw Exception("User data not found in database");
      }

      final data = doc.data()!;

      return UserModel(
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        role: data['role'] ?? 'farmer',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }

  /// 📝 REGISTER (SAFE)
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("Registration failed");

      await user.updateDisplayName(name);

      await firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'role': role,
      });

      return UserModel(
        name: name,
        email: email,
        role: role,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Registration failed");
    }
  }

  /// 🔴 GOOGLE LOGIN (IMPROVED)
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        throw Exception("Google Sign-In cancelled");
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) throw Exception("Google login failed");

      if ((user.displayName ?? '').trim().isNotEmpty) {
        await user.updateDisplayName(user.displayName!.trim());
      }

      final doc = await firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'role': 'farmer',
        });
      }

      return UserModel(
        name: user.displayName ?? '',
        email: user.email ?? '',
        role: 'farmer',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}

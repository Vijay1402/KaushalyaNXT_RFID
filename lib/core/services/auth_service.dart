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
        phone: data['phone'] ?? '',
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
    required String phone,
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
        'phone': phone,
      });

      return UserModel(
        name: name,
        email: email,
        role: role,
        phone: phone,
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
          'phone': '',
        });
      }

      return UserModel(
        name: user.displayName ?? '',
        email: user.email ?? '',
        role: 'farmer',
        phone: '',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final currentDoc =
          await firestore.collection('users').doc(user.uid).get();
      final currentData = currentDoc.data() ?? <String, dynamic>{};
      final normalizedName = name.trim();
      final normalizedEmail = email.trim();
      final normalizedPhone = phone.trim();
      final currentRole = (currentData['role'] ?? 'farmer').toString();

      if (normalizedEmail.isNotEmpty && normalizedEmail != (user.email ?? '')) {
        await user.verifyBeforeUpdateEmail(normalizedEmail);
      }

      if (normalizedName.isNotEmpty &&
          normalizedName != (user.displayName ?? '')) {
        await user.updateDisplayName(normalizedName);
      }

      await firestore.collection('users').doc(user.uid).set({
        'name': normalizedName,
        'email': normalizedEmail,
        'role': currentRole,
        'phone': normalizedPhone,
      }, SetOptions(merge: true));

      return UserModel(
        name: normalizedName,
        email: normalizedEmail,
        role: currentRole,
        phone: normalizedPhone,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Profile update failed");
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Password reset failed");
    }
  }
}

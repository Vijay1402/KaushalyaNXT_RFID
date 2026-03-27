import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ FIX: expose firestore
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// 🔐 CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 🔐 LOGIN
  Future<UserModel> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    final doc = await firestore.collection('users').doc(uid).get();
    final data = doc.data()!;

    return UserModel(
      name: data['name'],
      email: data['email'],
      role: data['role'],
    );
  }

  /// 📝 REGISTER
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    await firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role,
    });

    return UserModel(name: name, email: email, role: role);
  }

  /// 🔴 GOOGLE LOGIN
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();

    if (googleUser == null) {
      throw Exception("Google Sign-In cancelled");
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final user = userCredential.user!;
    final uid = user.uid;

    final doc = await firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      await firestore.collection('users').doc(uid).set({
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
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
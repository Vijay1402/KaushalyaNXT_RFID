import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user_model.dart';

class PhoneVerificationResult {
  final String? verificationId;
  final PhoneAuthCredential? credential;
  final bool autoVerified;

  const PhoneVerificationResult({
    this.verificationId,
    this.credential,
    this.autoVerified = false,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _normalizedRole(String role) {
    return role.trim().toLowerCase();
  }

  String normalizeManagerCode(String code) {
    return code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _buildManagerCodeBase(String name, String phone) {
    final normalizedName =
        name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final namePrefix = normalizedName.padRight(3, 'X').substring(0, 3);
    final phonePrefix = normalizedPhone.padRight(3, '0').substring(0, 3);
    return '$namePrefix$phonePrefix';
  }

  Future<String> _generateUniqueManagerCode(String name, String phone) async {
    final baseCode = _buildManagerCodeBase(name, phone);
    var candidate = baseCode;
    var suffix = 1;

    while (true) {
      final existing = await firestore
          .collection('users')
          .where('managerCode', isEqualTo: candidate)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return candidate;
      }

      candidate = '$baseCode${suffix.toString().padLeft(2, '0')}';
      suffix++;
    }
  }

  Future<Map<String, String>?> _findFarmManagerByCode(String code) async {
    final normalizedCode = normalizeManagerCode(code);
    if (normalizedCode.isEmpty) return null;

    final snapshot = await firestore
        .collection('users')
        .where('managerCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    final role = _normalizedRole((data['role'] ?? '').toString());
    if (role != 'farm_manager') return null;

    return {
      'id': doc.id,
      'name': (data['name'] ?? '').toString().trim(),
      'managerCode': (data['managerCode'] ?? normalizedCode).toString().trim(),
    };
  }

  UserModel _userModelFromData(
    Map<String, dynamic> data, {
    String fallbackPhone = '',
  }) {
    return UserModel(
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? 'farmer').toString(),
      phone: (data['phone'] ?? fallbackPhone).toString(),
      managerCode: (data['managerCode'] ?? '').toString(),
      farmManagerId: (data['farmManagerId'] ?? '').toString(),
      farmManagerName: (data['farmManagerName'] ?? '').toString(),
      farmManagerCode: (data['farmManagerCode'] ?? '').toString(),
    );
  }

  /// 🔐 CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  String normalizePhoneNumber(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.isNotEmpty) {
      return '+$digits';
    }
    return trimmed;
  }

  Future<PhoneVerificationResult> sendPhoneOtp(String phone) async {
    final completer = Completer<PhoneVerificationResult>();
    final normalizedPhone = normalizePhoneNumber(phone);

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationResult(
              credential: credential,
              autoVerified: true,
            ),
          );
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(e.message ?? e.code),
          );
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationResult(verificationId: verificationId),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationResult(verificationId: verificationId),
          );
        }
      },
    );

    return completer.future;
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

      return _userModelFromData(doc.data()!);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }

  Future<UserModel> loginWithPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _loginWithPhoneCredential(credential);
  }

  Future<UserModel> loginWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    return _loginWithPhoneCredential(credential);
  }

  Future<UserModel> _loginWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception("Phone login failed");

      final doc = await firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          try {
            await user.delete();
          } catch (_) {}
        }
        await _auth.signOut();
        throw Exception(
          "No account found for this phone number. Please register first.",
        );
      }

      return _userModelFromData(
        doc.data()!,
        fallbackPhone: user.phoneNumber ?? '',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "OTP login failed");
    }
  }

  /// 📝 REGISTER (SAFE)
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    String farmManagerCode = '',
  }) async {
    try {
      final normalizedRole = _normalizedRole(role);
      final normalizedName = name.trim();
      final normalizedEmail = email.trim();
      final normalizedPhone = phone.trim();

      String managerCode = '';
      String linkedFarmManagerId = '';
      String linkedFarmManagerName = '';
      String linkedFarmManagerCode = '';

      if (normalizedRole == 'farm_manager') {
        managerCode =
            await _generateUniqueManagerCode(normalizedName, normalizedPhone);
      } else if (normalizedRole == 'farmer') {
        final requestedManagerCode = normalizeManagerCode(farmManagerCode);
        if (requestedManagerCode.isNotEmpty) {
          final farmManager = await _findFarmManagerByCode(requestedManagerCode);
          if (farmManager == null) {
            throw Exception(
              "Invalid farm manager code. Please check and try again.",
            );
          }
          linkedFarmManagerId = farmManager['id'] ?? '';
          linkedFarmManagerName = farmManager['name'] ?? '';
          linkedFarmManagerCode = farmManager['managerCode'] ?? '';
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("Registration failed");

      await user.updateDisplayName(normalizedName);

      await firestore.collection('users').doc(user.uid).set({
        'name': normalizedName,
        'email': normalizedEmail,
        'role': role,
        'phone': normalizedPhone,
        'managerCode': managerCode,
        'farmManagerId': linkedFarmManagerId,
        'farmManagerName': linkedFarmManagerName,
        'farmManagerCode': linkedFarmManagerCode,
      });

      return UserModel(
        name: normalizedName,
        email: normalizedEmail,
        role: role,
        phone: normalizedPhone,
        managerCode: managerCode,
        farmManagerId: linkedFarmManagerId,
        farmManagerName: linkedFarmManagerName,
        farmManagerCode: linkedFarmManagerCode,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Registration failed");
    }
  }

  Future<UserModel> registerWithPhoneOtp({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    required String verificationId,
    required String smsCode,
  }) async {
    final phoneCredential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return registerWithPhoneCredential(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
      credential: phoneCredential,
    );
  }

  Future<UserModel> registerWithPhoneCredential({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    required PhoneAuthCredential credential,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phone);

    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception("Registration failed");

      final existingDoc =
          await firestore.collection('users').doc(user.uid).get();
      if (existingDoc.exists) {
        await _auth.signOut();
        throw Exception(
          "This phone number is already registered. Please login instead.",
        );
      }

      var linkedEmail = false;
      try {
        final emailCredential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        await user.linkWithCredential(emailCredential);
        linkedEmail = true;

        await user.updateDisplayName(name.trim());

        await firestore.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'role': role,
          'phone': normalizedPhone,
        });

        return UserModel(
          name: name.trim(),
          email: email.trim(),
          role: role,
          phone: normalizedPhone,
        );
      } on FirebaseAuthException catch (e) {
        if (!linkedEmail &&
            userCredential.additionalUserInfo?.isNewUser == true) {
          try {
            await user.delete();
          } catch (_) {}
        }
        await _auth.signOut();

        if (e.code == 'email-already-in-use' ||
            e.code == 'credential-already-in-use') {
          throw Exception(
            "This email is already registered. Please login instead.",
          );
        }
        throw Exception(e.message ?? "Registration failed");
      }
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
          'managerCode': '',
          'farmManagerId': '',
          'farmManagerName': '',
          'farmManagerCode': '',
        });
        return _userModelFromData({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'role': 'farmer',
          'phone': '',
          'managerCode': '',
          'farmManagerId': '',
          'farmManagerName': '',
          'farmManagerCode': '',
        });
      }

      return _userModelFromData(doc.data()!);
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
      final previousName = (currentData['name'] ?? '').toString().trim();
      final currentRole = (currentData['role'] ?? 'farmer').toString();
      final currentManagerCode = (currentData['managerCode'] ?? '').toString();
      final currentFarmManagerId =
          (currentData['farmManagerId'] ?? '').toString();
      final currentFarmManagerName =
          (currentData['farmManagerName'] ?? '').toString();
      final currentFarmManagerCode =
          (currentData['farmManagerCode'] ?? '').toString();

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
        'managerCode': currentManagerCode,
        'farmManagerId': currentFarmManagerId,
        'farmManagerName': currentFarmManagerName,
        'farmManagerCode': currentFarmManagerCode,
      }, SetOptions(merge: true));

      if (_normalizedRole(currentRole) == 'farm_manager' &&
          normalizedName.isNotEmpty &&
          normalizedName != previousName) {
        final linkedFarmers = await firestore
            .collection('users')
            .where('farmManagerId', isEqualTo: user.uid)
            .get();

        if (linkedFarmers.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final farmerDoc in linkedFarmers.docs) {
            batch.update(farmerDoc.reference, {
              'farmManagerName': normalizedName,
            });
          }
          await batch.commit();
        }
      }

      return UserModel(
        name: normalizedName,
        email: normalizedEmail,
        role: currentRole,
        phone: normalizedPhone,
        managerCode: currentManagerCode,
        farmManagerId: currentFarmManagerId,
        farmManagerName: currentFarmManagerName,
        farmManagerCode: currentFarmManagerCode,
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

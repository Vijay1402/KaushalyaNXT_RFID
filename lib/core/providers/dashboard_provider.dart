import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔥 FARMS DATA
final farmsProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('farms').snapshots();
});

/// 🔥 ISSUES DATA
final issuesProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('issues').snapshots();
});

/// 🔥 ALERTS DATA
final alertsProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('alerts').snapshots();
});
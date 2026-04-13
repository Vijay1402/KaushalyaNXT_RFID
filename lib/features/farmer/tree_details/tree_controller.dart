import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final treesProvider =
    StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.read(firestoreProvider);

  return firestore.collection('trees').snapshots();
});

final treeByIdProvider =
    StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, id) {
  final firestore = ref.read(firestoreProvider);

  return firestore.collection('trees').doc(id).snapshots();
});
final treeByIdFutureProvider =
    FutureProvider.family<DocumentSnapshot, String>((ref, treeId) {
  return FirebaseFirestore.instance
      .collection('trees')
      .doc(treeId)
      .get();
});
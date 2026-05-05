import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final usersSnapshotsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreProvider).collection('users').snapshots();
});

final farmsSnapshotsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreProvider).collection('farms').snapshots();
});

final treesSnapshotsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreProvider).collection('trees').snapshots();
});

final issuesSnapshotsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreProvider).collectionGroup('issues').snapshots();
});

final treeDocumentProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, treeDocId) {
  return ref
      .watch(firestoreProvider)
      .collection('trees')
      .doc(treeDocId)
      .snapshots();
});

final treeIssuePhotosProvider = FutureProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>(
  (ref, treeDocId) async {
    final snapshot = await ref
        .watch(firestoreProvider)
        .collection('trees')
        .doc(treeDocId)
        .collection('issues')
        .where('hasImage', isEqualTo: true)
        .get();

    return snapshot.docs.where((doc) {
      return (doc.data()['imageUrl'] ?? '').toString().trim().isNotEmpty;
    }).toList(growable: false);
  },
);

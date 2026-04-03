import 'package:cloud_firestore/cloud_firestore.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔥 STREAM FOR LIVE SYNC STATUS
  Stream<DocumentSnapshot> getSyncStatus() {
    return _firestore
        .collection('sync')
        .doc('status')
        .snapshots();
  }

  /// 🔄 UPDATE LAST SYNC TIME
  Future<void> updateLastSync() async {
    await _firestore.collection('sync').doc('status').set({
      "lastSync": FieldValue.serverTimestamp(),
      "status": "online",
    }, SetOptions(merge: true));
  }
}
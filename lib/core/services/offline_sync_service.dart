import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/farmer/tree_details/tree_controller.dart';
import 'local_cache_service.dart';

class OfflineSyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalCacheService _cache = LocalCacheService();

  bool _isSyncing = false;

  Future<void> syncPendingTreeWrites() async {
    if (_isSyncing) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _isSyncing = true;
    try {
      final pending = await _cache.getPendingTreeSyncs(user.uid);
      for (final tree in pending) {
        final docId = treeDocIdOf(tree);
        if (docId.isEmpty) continue;

        final payload = <String, dynamic>{
          'treeId': (tree['treeId'] ?? '').toString(),
          'rfid': (tree['rfid'] ?? docId).toString(),
          'rfidTid': (tree['rfidTid'] ?? '').toString(),
          'farmerName': (tree['farmerName'] ?? '').toString(),
          'ownerName': (tree['ownerName'] ?? '').toString(),
          'userId': user.uid,
          'userEmail': user.email ?? '',
          'healthStatus': (tree['healthStatus'] ?? '0').toString(),
          'healthStatusName': (tree['healthStatusName'] ?? '').toString(),
          'species': (tree['species'] ?? '').toString(),
          'speciesCode': (tree['speciesCode'] ?? '').toString(),
          'lastYieldKg': (tree['lastYieldKg'] as num?)?.toDouble() ?? 0,
          'treeAge': (tree['treeAge'] as num?)?.toInt() ?? 0,
          'age': (tree['age'] as num?)?.toInt() ?? 0,
          'harvestMonth': (tree['harvestMonth'] ?? '').toString(),
          'isScanned': tree['isScanned'] == true,
          'location': (tree['location'] ?? '').toString(),
          'latitude': (tree['latitude'] as num?)?.toDouble() ?? 0,
          'longitude': (tree['longitude'] as num?)?.toDouble() ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final lastInspection = DateTime.tryParse(
          (tree['lastinspectiondate'] ?? '').toString(),
        );
        if (lastInspection != null) {
          payload['lastinspectiondate'] = Timestamp.fromDate(lastInspection);
        }

        final createdAt =
            DateTime.tryParse((tree['createdAt'] ?? '').toString());
        if (createdAt == null) {
          payload['createdAt'] = FieldValue.serverTimestamp();
        }

        await _firestore.collection('trees').doc(docId).set(
              payload,
              SetOptions(merge: true),
            );
        await _cache.removePendingTreeSync(user.uid, docId);
      }

      final pendingScans = await _cache.getPendingScanHistory(user.uid);
      for (final scan in pendingScans) {
        final scanId = (scan['scanId'] ?? '').toString().trim();
        if (scanId.isEmpty) continue;

        await _firestore.collection('scan_history').doc(scanId).set({
          'scanId': scanId,
          'treeId': (scan['treeId'] ?? '').toString(),
          'rfid': (scan['rfid'] ?? scan['epc'] ?? '').toString(),
          'epc': (scan['epc'] ?? '').toString(),
          'tid': (scan['tid'] ?? '').toString(),
          'healthstatus': (scan['healthstatus'] ?? '').toString(),
          'latitude': scan['latitude'],
          'longitude': scan['longitude'],
          'date': FieldValue.serverTimestamp(),
          'savedAtLocal': (scan['savedAt'] ?? '').toString(),
          'savedAt': FieldValue.serverTimestamp(),
          'source': (scan['source'] ?? 'rfid_scan').toString(),
          'userId': user.uid,
          'userEmail': user.email ?? '',
        }, SetOptions(merge: true));

        await _cache.removePendingScanHistory(user.uid, scanId);
      }
    } finally {
      _isSyncing = false;
    }
  }
}

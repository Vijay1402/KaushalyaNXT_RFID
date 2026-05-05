import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';
import '../../features/farmer/tree_details/tree_controller.dart';
import 'local_cache_service.dart';

class OfflineSyncService {
  OfflineSyncService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LocalCacheService? cache,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _cache = cache ?? LocalCacheService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalCacheService _cache;

  bool _isSyncing = false;

  Future<Map<String, String>> _currentManagerLinkFields(
    User user,
    Map<String, dynamic> tree,
  ) async {
    final cachedUser = await _cache.getUser();
    final role = (cachedUser?.role ?? '').toString().trim().toLowerCase();
    final cachedName = (cachedUser?.name ?? '').toString().trim();
    final existingManagerId =
        (tree['farmManagerId'] ?? tree['managerId'] ?? '').toString().trim();
    final existingManagerName =
        (tree['farmManagerName'] ?? '').toString().trim();
    final existingManagerCode =
        (tree['farmManagerCode'] ?? tree['managerCode'] ?? '')
            .toString()
            .trim();

    final linkedManagerId = (cachedUser?.farmManagerId ?? '').toString().trim();
    final linkedManagerName =
        (cachedUser?.farmManagerName ?? '').toString().trim();
    final linkedManagerCode =
        (cachedUser?.farmManagerCode ?? '').toString().trim();
    final ownManagerCode = (cachedUser?.managerCode ?? '').toString().trim();

    final effectiveManagerId = existingManagerId.isNotEmpty
        ? existingManagerId
        : role == 'farm_manager'
            ? user.uid
            : linkedManagerId;
    final effectiveManagerName = existingManagerName.isNotEmpty
        ? existingManagerName
        : role == 'farm_manager'
            ? (cachedName.isNotEmpty
                ? cachedName
                : (tree['ownerName'] ?? tree['farmerName'] ?? '')
                    .toString()
                    .trim())
            : linkedManagerName;
    final effectiveManagerCode = existingManagerCode.isNotEmpty
        ? existingManagerCode
        : role == 'farm_manager'
            ? ownManagerCode
            : linkedManagerCode;

    return <String, String>{
      'managerId': effectiveManagerId,
      'farmManagerId': effectiveManagerId,
      'farmManagerName': effectiveManagerName,
      'managerCode': effectiveManagerCode,
      'farmManagerCode': effectiveManagerCode,
    };
  }

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
        final managerFields = await _currentManagerLinkFields(user, tree);

        final payload = <String, dynamic>{
          'treeId': (tree['treeId'] ?? '').toString(),
          'rfid': (tree['rfid'] ?? docId).toString(),
          'rfidTid': (tree['rfidTid'] ?? '').toString(),
          'farmerName': (tree['farmerName'] ?? '').toString(),
          'ownerName': (tree['ownerName'] ?? '').toString(),
          'userId': user.uid,
          'userEmail': user.email ?? '',
          ...managerFields,
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

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(
    auth: ref.read(firebaseAuthProvider),
    firestore: ref.read(firestoreProvider),
  );
});

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/local_cache_service.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../auth/providers/auth_provider.dart';

const String treeDocIdField = '_docId';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final treeIssueControllerProvider = Provider<TreeIssueController>((ref) {
  return TreeIssueController(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
    storage: ref.read(firebaseStorageProvider),
    cache: ref.read(localCacheServiceProvider),
  );
});

class _TreeOwnerQuery {
  final String field;
  final Object value;

  const _TreeOwnerQuery({
    required this.field,
    required this.value,
  });
}

class TreeIssueController {
  TreeIssueController({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseStorage storage,
    required LocalCacheService cache,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage,
        _cache = cache;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final LocalCacheService _cache;

  Future<void> reportIssue({
    required String treeDocId,
    required String treeId,
    required String species,
    required String healthStatus,
    String? ownerName,
    String? note,
    String? imagePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be logged in to report an issue');
    }

    final trimmedTreeDocId = treeDocId.trim();
    if (trimmedTreeDocId.isEmpty) {
      throw ArgumentError('Tree document id is required');
    }

    final reportId = _firestore
        .collection('trees')
        .doc(trimmedTreeDocId)
        .collection('issues')
        .doc()
        .id;

    final issueData = <String, dynamic>{
      'reportId': reportId,
      'treeDocId': trimmedTreeDocId,
      'treeId': treeId.trim(),
      'species': species.trim(),
      'healthStatus': healthStatus.trim(),
      'ownerName': ownerName?.trim() ?? '',
      'note': note?.trim() ?? '',
      'localImagePath': imagePath?.trim() ?? '',
      'status': 'open',
      'reportedByUid': user.uid,
      'reportedByEmail': user.email?.trim() ?? '',
      'createdAtLocal': DateTime.now().toIso8601String(),
    };

    await _cache.savePendingIssue(user.uid, issueData);
    await _cache.saveIssueHistoryEntry(user.uid, issueData);
    await syncPendingIssues();
  }

  Future<void> syncPendingIssues() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final issues = await _cache.getPendingIssues(user.uid);
    for (final issue in issues) {
      try {
        await _syncSinglePendingIssue(user.uid, issue);
      } catch (_) {
        // Keep pending when network/storage is unavailable.
      }
    }
  }

  Future<void> _syncSinglePendingIssue(
    String userId,
    Map<String, dynamic> issue,
  ) async {
    final treeDocId = (issue['treeDocId'] ?? '').toString().trim();
    final reportId = (issue['reportId'] ?? '').toString().trim();
    if (treeDocId.isEmpty || reportId.isEmpty) return;

    var imageUrl = (issue['imageUrl'] ?? '').toString().trim();
    final localImagePath = (issue['localImagePath'] ?? '').toString().trim();
    if (imageUrl.isEmpty && localImagePath.isNotEmpty) {
      final imageFile = File(localImagePath);
      if (await imageFile.exists()) {
        final extension = localImagePath.contains('.')
            ? localImagePath.substring(localImagePath.lastIndexOf('.'))
            : '.jpg';
        final storageRef = _storage.ref().child(
              'tree_issue_reports/$userId/$treeDocId/$reportId$extension',
            );
        await storageRef.putFile(imageFile);
        imageUrl = await storageRef.getDownloadURL();
      }
    }

    await _firestore
        .collection('trees')
        .doc(treeDocId)
        .collection('issues')
        .doc(reportId)
        .set({
      'reportId': reportId,
      'treeDocId': treeDocId,
      'treeId': (issue['treeId'] ?? '').toString(),
      'species': (issue['species'] ?? '').toString(),
      'healthStatus': (issue['healthStatus'] ?? '').toString(),
      'ownerName': (issue['ownerName'] ?? '').toString(),
      'note': (issue['note'] ?? '').toString(),
      'hasImage': imageUrl.isNotEmpty,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'status': (issue['status'] ?? 'open').toString(),
      'reportedByUid': (issue['reportedByUid'] ?? '').toString(),
      'reportedByEmail': (issue['reportedByEmail'] ?? '').toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('issue_history')
        .doc(reportId)
        .set({
      'reportId': reportId,
      'treeDocId': treeDocId,
      'treeId': (issue['treeId'] ?? '').toString(),
      'species': (issue['species'] ?? '').toString(),
      'healthStatus': (issue['healthStatus'] ?? '').toString(),
      'ownerName': (issue['ownerName'] ?? '').toString(),
      'note': (issue['note'] ?? '').toString(),
      'hasImage': imageUrl.isNotEmpty,
      'imageUrl': imageUrl,
      'status': (issue['status'] ?? 'open').toString(),
      'reportedByUid': (issue['reportedByUid'] ?? '').toString(),
      'reportedByEmail': (issue['reportedByEmail'] ?? '').toString(),
      'createdAtLocal': (issue['createdAtLocal'] ?? '').toString(),
      'savedAt': FieldValue.serverTimestamp(),
      'syncedAtLocal': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await _cache.saveIssueHistoryEntry(userId, {
      ...issue,
      'imageUrl': imageUrl,
      'hasImage': imageUrl.isNotEmpty,
      'syncedAtLocal': DateTime.now().toIso8601String(),
    });

    await _cache.removePendingIssue(userId, reportId);
  }
}

const List<String> _uidOwnerFields = <String>[
  'userId',
  'uid',
  'ownerId',
  'farmerId',
  'createdBy',
];

const List<String> _emailOwnerFields = <String>[
  'email',
  'userEmail',
  'ownerEmail',
  'farmerEmail',
];

String treeDocIdOf(Map<String, dynamic> tree) {
  return (tree[treeDocIdField] ?? '').toString();
}

Map<String, dynamic> treeWithDocId(String docId, Map<String, dynamic> data) {
  return <String, dynamic>{
    treeDocIdField: docId,
    ...data,
  };
}

int _tagHealthStatusFromTree(Map<String, dynamic> treeData) {
  switch ((treeData['healthStatus'] ?? '').toString()) {
    case '0':
      return 1;
    case '1':
      return 2;
    case '2':
    case '3':
      return 3;
    default:
      return 0;
  }
}

int _tagSpeciesFromTree(Map<String, dynamic> treeData) {
  final speciesCode =
      (treeData['speciesCode'] ?? treeData['species'] ?? '').toString();
  switch (speciesCode.trim().toLowerCase()) {
    case 'mango':
      return 1;
    case 'coconut':
      return 2;
    case 'arecanut':
      return 3;
    case 'cashew':
      return 4;
    default:
      return 0;
  }
}

int _tagLastInspectionUnixFromTree(Map<String, dynamic> treeData) {
  final raw = treeData['lastinspectiondate'] ??
      treeData['lastInspectionDate'] ??
      treeData['updatedAt'];
  if (raw is Timestamp) {
    return raw.seconds;
  }
  if (raw is DateTime) {
    return raw.millisecondsSinceEpoch ~/ 1000;
  }
  if (raw is Map && raw['_seconds'] != null) {
    return (raw['_seconds'] as num).toInt();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed != null) {
      return parsed.millisecondsSinceEpoch ~/ 1000;
    }
  }
  return 0;
}

Map<String, dynamic>? tagSnapshotFromTree(Map<String, dynamic> treeData) {
  final epc = (treeData['rfid'] ?? treeDocIdOf(treeData))
      .toString()
      .trim()
      .toUpperCase();
  if (epc.isEmpty) return null;

  final farmerName =
      (treeData['farmerName'] ?? treeData['ownerName'] ?? '').toString().trim();
  final treeAge = (treeData['treeAge'] as num?)?.toInt() ??
      (treeData['age'] as num?)?.toInt() ??
      0;
  final lastYieldKg = (treeData['lastYieldKg'] as num?)?.toDouble() ?? 0.0;

  return <String, dynamic>{
    'epc': epc,
    'tid': (treeData['rfidTid'] ?? '').toString().trim().toUpperCase(),
    'treeId': (treeData['treeId'] ?? '').toString().trim(),
    'farmerName': farmerName,
    'lastInspectionUnix': _tagLastInspectionUnixFromTree(treeData),
    'healthStatus': _tagHealthStatusFromTree(treeData),
    'lastYieldKg': lastYieldKg,
    'treeAgeYears': treeAge,
    'species': _tagSpeciesFromTree(treeData),
    'source': 'firestore',
    'savedAt': DateTime.now().toIso8601String(),
  };
}

Future<void> cacheTagSnapshotFromTree(
  LocalCacheService cache,
  String userId,
  Map<String, dynamic> treeData,
) async {
  final snapshot = tagSnapshotFromTree(treeData);
  if (snapshot == null) return;
  await cache.saveWrittenTag(userId, snapshot);
}

Future<void> cacheTagSnapshotsFromTrees(
  LocalCacheService cache,
  String userId,
  List<Map<String, dynamic>> trees,
) async {
  for (final tree in trees) {
    await cacheTagSnapshotFromTree(cache, userId, tree);
  }
}

Future<_TreeOwnerQuery> _resolveTreeOwnerQuery({
  required FirebaseFirestore firestore,
  required User user,
}) async {
  final candidates = <_TreeOwnerQuery>[
    ..._uidOwnerFields.map(
      (field) => _TreeOwnerQuery(field: field, value: user.uid),
    ),
  ];

  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) {
    candidates.addAll(
      _emailOwnerFields.map(
        (field) => _TreeOwnerQuery(field: field, value: email),
      ),
    );
  }

  for (final candidate in candidates) {
    try {
      final snapshot = await firestore
          .collection('trees')
          .where(candidate.field, isEqualTo: candidate.value)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return candidate;
      }
    } on FirebaseException {
      // Ignore missing/unsupported fields and continue trying other candidates.
    }
  }

  return _TreeOwnerQuery(field: 'userId', value: user.uid);
}

bool _treeBelongsToUser(Map<String, dynamic> data, User user) {
  final email = user.email?.trim();

  for (final field in _uidOwnerFields) {
    if ((data[field]?.toString().trim() ?? '') == user.uid) {
      return true;
    }
  }

  if (email != null && email.isNotEmpty) {
    for (final field in _emailOwnerFields) {
      if ((data[field]?.toString().trim() ?? '') == email) {
        return true;
      }
    }
  }

  return false;
}

Future<String?> findOwnedTreeDocumentIdByTreeId({
  required FirebaseFirestore firestore,
  required User user,
  required String treeId,
}) async {
  final normalizedTreeId = treeId.trim().toLowerCase();
  if (normalizedTreeId.isEmpty) return null;

  final cache = LocalCacheService();
  final cachedDocId = await cache.findTreeDocIdByTreeId(user.uid, treeId);
  if (cachedDocId != null) {
    return cachedDocId;
  }

  final ownerQuery = await _resolveTreeOwnerQuery(
    firestore: firestore,
    user: user,
  );

  final snapshot = await firestore
      .collection('trees')
      .where(ownerQuery.field, isEqualTo: ownerQuery.value)
      .get();

  final trees = snapshot.docs
      .map((doc) => treeWithDocId(doc.id, doc.data()))
      .toList(growable: false);
  await cache.saveTrees(user.uid, trees);

  for (final tree in trees) {
    final docTreeId = (tree['treeId'] ?? '').toString().trim().toLowerCase();
    if (docTreeId == normalizedTreeId) {
      return treeDocIdOf(tree);
    }
  }

  return null;
}

final treesProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async* {
    final firestore = ref.read(firestoreProvider);
    final auth = ref.read(firebaseAuthProvider);
    final cache = ref.read(localCacheServiceProvider);
    final user = auth.currentUser;

    if (user == null) {
      yield const [];
      return;
    }

    final cachedTrees = await cache.getTrees(user.uid);
    if (cachedTrees.isNotEmpty) {
      yield cachedTrees;
    }

    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    if (!isOnline) {
      if (cachedTrees.isEmpty) {
        yield const [];
      }
      return;
    }

    try {
      final ownerQuery = await _resolveTreeOwnerQuery(
        firestore: firestore,
        user: user,
      );

      await for (final snapshot in firestore
          .collection('trees')
          .where(ownerQuery.field, isEqualTo: ownerQuery.value)
          .snapshots()) {
        final trees = snapshot.docs
            .map((doc) => treeWithDocId(doc.id, doc.data()))
            .toList(growable: false);
        await cache.saveTrees(user.uid, trees);
        await cacheTagSnapshotsFromTrees(cache, user.uid, trees);
        yield trees;
      }
    } catch (_) {
      if (cachedTrees.isEmpty) {
        yield const [];
      }
    }
  },
);

final treeByIdProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, id) async* {
    final firestore = ref.read(firestoreProvider);
    final auth = ref.read(firebaseAuthProvider);
    final cache = ref.read(localCacheServiceProvider);
    final user = auth.currentUser;

    if (user == null) {
      yield null;
      return;
    }

    final cachedTree = await cache.getTreeByDocId(user.uid, id);
    if (cachedTree != null) {
      yield cachedTree;
    }

    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;
    if (!isOnline) {
      yield cachedTree;
      return;
    }

    try {
      await for (final doc
          in firestore.collection('trees').doc(id).snapshots()) {
        if (!doc.exists) {
          yield null;
          continue;
        }

        final data = doc.data();
        if (data == null || !_treeBelongsToUser(data, user)) {
          yield null;
          continue;
        }

        final tree = treeWithDocId(doc.id, data);
        await cache.saveTree(user.uid, tree);
        await cacheTagSnapshotFromTree(cache, user.uid, tree);
        yield tree;
      }
    } catch (_) {
      yield cachedTree;
    }
  },
);

final treeSyncStatusProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, docId) async {
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null || docId.trim().isEmpty) return true;

  final pending =
      await ref.read(localCacheServiceProvider).getPendingTreeSyncs(user.uid);
  return !pending.any((item) => treeDocIdOf(item) == docId);
});

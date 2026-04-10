import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';

const String treeDocIdField = '_docId';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

class _TreeOwnerQuery {
  final String field;
  final Object value;

  const _TreeOwnerQuery({
    required this.field,
    required this.value,
  });
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
        yield tree;
      }
    } catch (_) {
      yield cachedTree;
    }
  },
);

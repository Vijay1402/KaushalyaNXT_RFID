import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final ownerQuery = await _resolveTreeOwnerQuery(
    firestore: firestore,
    user: user,
  );

  final snapshot = await firestore
      .collection('trees')
      .where(ownerQuery.field, isEqualTo: ownerQuery.value)
      .get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final docTreeId = (data['treeId'] ?? '').toString().trim().toLowerCase();
    if (docTreeId == normalizedTreeId) {
      return doc.id;
    }
  }

  return null;
}

final treesProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>(
        (ref) async* {
  final firestore = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);
  final user = auth.currentUser;

  if (user == null) {
    yield* firestore
        .collection('trees')
        .where('userId', isEqualTo: '__no_authenticated_user__')
        .snapshots();
    return;
  }

  final ownerQuery = await _resolveTreeOwnerQuery(
    firestore: firestore,
    user: user,
  );

  yield* firestore
      .collection('trees')
      .where(ownerQuery.field, isEqualTo: ownerQuery.value)
      .snapshots();
});

final treeByIdProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, id) async* {
  final firestore = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);
  final user = auth.currentUser;

  if (user == null) {
    yield null;
    return;
  }

  yield* firestore.collection('trees').doc(id).snapshots().map((doc) {
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return _treeBelongsToUser(data, user) ? doc : null;
  });
});

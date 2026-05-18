import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/local_cache_service.dart';
import 'farm_manager_data.dart';

class FarmManagerOverviewData {
  const FarmManagerOverviewData({
    required this.scope,
    required this.farmDocs,
    required this.treeDocs,
    required this.scopedTrees,
    required this.farms,
    required this.issues,
    required this.usingDerivedIssues,
  });

  final FarmManagerScope scope;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> farmDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> treeDocs;
  final List<Map<String, dynamic>> scopedTrees;
  final List<FarmManagerFarm> farms;
  final List<FarmManagerIssue> issues;
  final bool usingDerivedIssues;
}

const FarmManagerScope _globalFarmManagerScope = FarmManagerScope(
  managerUid: '',
  managerEmail: '',
  managerCode: '',
  linkedFarmerIds: <String>{},
  linkedFarmerEmails: <String>{},
);

final farmManagerScopeProvider =
    FutureProvider.autoDispose<FarmManagerScope>((ref) {
  return loadFarmManagerScope(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final farmManagerOverviewProvider =
    StreamProvider.autoDispose<FarmManagerOverviewData>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);
  final scope = await ref.watch(farmManagerScopeProvider.future);
  final currentUser = auth.currentUser;
  final cachedTrees = currentUser == null
      ? const <Map<String, dynamic>>[]
      : await LocalCacheService().getTrees(currentUser.uid);

  yield _overviewFromTreeMaps(
    scope: scope,
    trees: cachedTrees,
  );

  yield* _watchFarmOverview(
    firestore: ref.watch(firestoreProvider),
    scope: scope,
  );
});

final globalFarmOverviewProvider =
    StreamProvider.autoDispose<FarmManagerOverviewData>((ref) {
  return _watchFarmOverview(
    firestore: ref.watch(firestoreProvider),
    scope: _globalFarmManagerScope,
  );
});

final managedFarmersProvider =
    StreamProvider.autoDispose<List<FarmManagerManagedFarmer>>((ref) {
  return watchManagedFarmers(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final linkedFarmerForFarmProvider = FutureProvider.autoDispose
    .family<FarmManagerLinkedFarmer?, FarmManagerFarm>(
  (ref, farm) {
    return loadLinkedFarmerForFarm(
      farm,
      firestore: ref.watch(firestoreProvider),
    );
  },
);

final farmManagerPendingSyncCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return 0;
  }

  final cache = LocalCacheService();
  final pendingTrees = await cache.getPendingTreeSyncs(user.uid);
  final pendingIssues = await cache.getPendingIssues(user.uid);
  return pendingTrees.length + pendingIssues.length;
});

Stream<FarmManagerOverviewData> _watchFarmOverview({
  required FirebaseFirestore firestore,
  required FarmManagerScope scope,
}) async* {
  yield _overviewFromTreeMaps(
    scope: scope,
    trees: const <Map<String, dynamic>>[],
  );

  yield* Stream<FarmManagerOverviewData>.multi((controller) {
    QuerySnapshot<Map<String, dynamic>>? latestFarmSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestTreeSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestIssueSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestTopLevelIssueSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestUserSnapshot;
    var usingDerivedIssues = false;

    void emitOverview() {
      final farmDocs = latestFarmSnapshot?.docs ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final treeDocs = latestTreeSnapshot?.docs ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final scopedTrees = buildScopedTrees(treeDocs, scope);
      final farms = buildFarmSummaries(
        farmDocs: farmDocs,
        scopedTrees: scopedTrees,
        scope: scope,
      );
      final allIssueDocs = [
        ...(latestIssueSnapshot?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ...(latestTopLevelIssueSnapshot?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
      ];
      final trackerIssues = allIssueDocs.isEmpty
          ? buildDerivedIssuesFromTrees(scopedTrees)
          : buildIssueSummaries(
              issueDocs: allIssueDocs,
              scopedTrees: scopedTrees,
              scope: scope,
            );
      final supportIssues = _buildSupportIssuesFromUsers(
        userDocs: latestUserSnapshot?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        scope: scope,
      );
      final issues = _uniqueOverviewIssues([...trackerIssues, ...supportIssues])
        ..sort((left, right) {
          final rightTime =
              right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final leftTime =
              left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightTime.compareTo(leftTime);
        });

      controller.add(
        FarmManagerOverviewData(
          scope: scope,
          farmDocs: farmDocs,
          treeDocs: treeDocs,
          scopedTrees: scopedTrees,
          farms: farms,
          issues: issues,
          usingDerivedIssues: usingDerivedIssues || latestIssueSnapshot == null,
        ),
      );
    }

    final farmSubscription = firestore.collection('farms').snapshots().listen(
      (snapshot) {
        latestFarmSnapshot = snapshot;
        emitOverview();
      },
      onError: (Object _, StackTrace __) {
        latestFarmSnapshot = null;
        emitOverview();
      },
    );

    final treeSubscription = firestore.collection('trees').snapshots().listen(
      (snapshot) {
        latestTreeSnapshot = snapshot;
        emitOverview();
      },
      onError: (Object _, StackTrace __) {
        latestTreeSnapshot = null;
        emitOverview();
      },
    );

    final issueSubscription =
        firestore.collectionGroup('issues').snapshots().listen(
      (snapshot) {
        latestIssueSnapshot = snapshot;
        usingDerivedIssues = false;
        emitOverview();
      },
      onError: (Object _, StackTrace __) {
        latestIssueSnapshot = null;
        usingDerivedIssues = true;
        emitOverview();
      },
    );

    final topLevelIssueSubscription =
        firestore.collection('issues').snapshots().listen(
      (snapshot) {
        latestTopLevelIssueSnapshot = snapshot;
        emitOverview();
      },
      onError: (Object _, StackTrace __) {
        latestTopLevelIssueSnapshot = null;
        emitOverview();
      },
    );

    final userSubscription = firestore.collection('users').snapshots().listen(
      (snapshot) {
        latestUserSnapshot = snapshot;
        emitOverview();
      },
      onError: (Object _, StackTrace __) {
        latestUserSnapshot = null;
        emitOverview();
      },
    );

    controller.onCancel = () async {
      await farmSubscription.cancel();
      await treeSubscription.cancel();
      await issueSubscription.cancel();
      await topLevelIssueSubscription.cancel();
      await userSubscription.cancel();
    };
  });
}

FarmManagerOverviewData _overviewFromTreeMaps({
  required FarmManagerScope scope,
  required List<Map<String, dynamic>> trees,
}) {
  final scopedTrees = scope.shouldFilter
      ? trees.where((tree) => treeMatchesScope(tree, scope)).toList()
      : trees;

  return FarmManagerOverviewData(
    scope: scope,
    farmDocs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    treeDocs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    scopedTrees: scopedTrees,
    farms: buildDerivedFarmSummaries(scopedTrees),
    issues: buildDerivedIssuesFromTrees(scopedTrees),
    usingDerivedIssues: true,
  );
}

List<FarmManagerIssue> _uniqueOverviewIssues(List<FarmManagerIssue> issues) {
  final unique = <String, FarmManagerIssue>{};
  for (final issue in issues) {
    final key = firstNonEmptyString([
      issue.id,
      issue.treeDocId.isEmpty ? '' : '${issue.treeDocId}:${issue.note}',
      '${issue.ownerName}:${issue.title}:${issue.note}',
    ]);
    unique[key] = issue;
  }
  return unique.values.toList(growable: false);
}

List<FarmManagerIssue> _buildSupportIssuesFromUsers({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
  required FarmManagerScope scope,
}) {
  final issues = <FarmManagerIssue>[];

  for (final doc in userDocs) {
    final userData = <String, dynamic>{
      '_docId': doc.id,
      ...doc.data(),
    };
    if (scope.shouldFilter && !_userMatchesScope(userData, scope)) {
      continue;
    }

    final rawIssue = userData['latestSupportIssue'];
    if (rawIssue is! Map) {
      continue;
    }
    final issue = Map<String, dynamic>.from(rawIssue);
    final note = firstNonEmptyString([
      issue['note'],
      userData['latestSupportIssueMessage'],
    ]);
    if (note.isEmpty) {
      continue;
    }

    final status = normalizedIssueStatus(
      issue['status'] ?? userData['latestSupportIssueStatus'] ?? 'open',
    );
    final farmerName = firstNonEmptyString(
      [issue['farmerName'], issue['ownerName'], userData['name']],
      fallback: 'Farmer',
    );

    issues.add(
      FarmManagerIssue(
        id: firstNonEmptyString(
          [issue['reportId']],
          fallback: 'support_${doc.id}',
        ),
        treeDocId: '',
        treeId: 'Support',
        farmId: 'support',
        farmLabel: 'Support',
        title: firstNonEmptyString([issue['title'], note]),
        note: note,
        status: status,
        severity: issueSeverity(
          status: status,
          healthLabelValue: 'Unknown',
        ),
        healthLabel: 'Support',
        ownerName: farmerName,
        hasImage: false,
        createdAt: parseDateTime(
          userData['latestSupportIssueAt'] ?? issue['createdAtLocal'],
        ),
      ),
    );
  }

  return issues;
}

bool _userMatchesScope(
  Map<String, dynamic> user,
  FarmManagerScope scope,
) {
  if (!scope.shouldFilter) {
    return true;
  }

  final userId = firstNonEmptyString([
    user['_docId'],
    user['userId'],
    user['uid'],
    user['farmerId'],
  ]);
  if (userId.isNotEmpty && scope.linkedFarmerIds.contains(userId)) {
    return true;
  }

  final email = firstNonEmptyString([
    user['email'],
    user['userEmail'],
    user['farmerEmail'],
  ]).toLowerCase();
  if (email.isNotEmpty &&
      scope.linkedFarmerEmails
          .map((value) => value.trim().toLowerCase())
          .contains(email)) {
    return true;
  }

  final managerId = firstNonEmptyString([
    user['farmManagerId'],
    user['managerId'],
  ]);
  if (managerId.isNotEmpty && managerId == scope.managerUid) {
    return true;
  }

  final managerCode = firstNonEmptyString([
    user['farmManagerCode'],
    user['managerCode'],
  ]);
  return managerCode.isNotEmpty &&
      scope.managerCode.isNotEmpty &&
      managerCode == scope.managerCode;
}

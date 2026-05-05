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
  final scope = await ref.watch(farmManagerScopeProvider.future);
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
  yield* Stream<FarmManagerOverviewData>.multi((controller) {
    QuerySnapshot<Map<String, dynamic>>? latestFarmSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestTreeSnapshot;
    QuerySnapshot<Map<String, dynamic>>? latestIssueSnapshot;
    var usingDerivedIssues = false;

    void emitOverview() {
      final treeSnapshot = latestTreeSnapshot;
      if (treeSnapshot == null) {
        return;
      }

      final farmDocs = latestFarmSnapshot?.docs ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final treeDocs = treeSnapshot.docs;
      final scopedTrees = buildScopedTrees(treeDocs, scope);
      final farms = buildFarmSummaries(
        farmDocs: farmDocs,
        scopedTrees: scopedTrees,
        scope: scope,
      );
      final issues = latestIssueSnapshot == null
          ? buildDerivedIssuesFromTrees(scopedTrees)
          : buildIssueSummaries(
              issueDocs: latestIssueSnapshot!.docs,
              scopedTrees: scopedTrees,
              scope: scope,
            );

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
      onError: controller.addError,
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

    controller.onCancel = () async {
      await farmSubscription.cancel();
      await treeSubscription.cancel();
      await issueSubscription.cancel();
    };
  });
}

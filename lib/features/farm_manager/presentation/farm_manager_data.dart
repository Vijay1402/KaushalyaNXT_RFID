import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FarmManagerScope {
  const FarmManagerScope({
    required this.managerUid,
    required this.managerEmail,
    required this.managerCode,
    required this.linkedFarmerIds,
    required this.linkedFarmerEmails,
  });

  final String managerUid;
  final String managerEmail;
  final String managerCode;
  final Set<String> linkedFarmerIds;
  final Set<String> linkedFarmerEmails;

  bool get hasLinkedFarmers => linkedFarmerIds.length > 1;
}

class FarmManagerFarm {
  const FarmManagerFarm({
    required this.id,
    required this.name,
    required this.location,
    required this.totalTrees,
    required this.healthyTrees,
    required this.needsAttentionTrees,
    required this.atRiskTrees,
    required this.scannedTrees,
    required this.areaAcres,
    required this.farmerName,
    required this.farmerPhone,
    required this.farmerEmail,
    required this.latitude,
    required this.longitude,
    required this.trees,
  });

  final String id;
  final String name;
  final String location;
  final int totalTrees;
  final int healthyTrees;
  final int needsAttentionTrees;
  final int atRiskTrees;
  final int scannedTrees;
  final double areaAcres;
  final String farmerName;
  final String farmerPhone;
  final String farmerEmail;
  final double? latitude;
  final double? longitude;
  final List<Map<String, dynamic>> trees;

  int get alertCount => needsAttentionTrees + atRiskTrees;
  int get healthPercent =>
      totalTrees == 0 ? 0 : ((healthyTrees / totalTrees) * 100).round();
  bool get hasCoordinates => latitude != null && longitude != null;
  List<String> get treeDocIds => trees
      .map((tree) => (tree['_docId'] ?? '').toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

class FarmManagerIssue {
  const FarmManagerIssue({
    required this.id,
    required this.treeDocId,
    required this.treeId,
    required this.farmId,
    required this.farmLabel,
    required this.title,
    required this.note,
    required this.status,
    required this.severity,
    required this.healthLabel,
    required this.ownerName,
    required this.hasImage,
    required this.createdAt,
  });

  final String id;
  final String treeDocId;
  final String treeId;
  final String farmId;
  final String farmLabel;
  final String title;
  final String note;
  final String status;
  final String severity;
  final String healthLabel;
  final String ownerName;
  final bool hasImage;
  final DateTime? createdAt;
}

Future<FarmManagerScope> loadFarmManagerScope() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    return const FarmManagerScope(
      managerUid: '',
      managerEmail: '',
      managerCode: '',
      linkedFarmerIds: <String>{},
      linkedFarmerEmails: <String>{},
    );
  }

  final firestore = FirebaseFirestore.instance;
  String managerCode = '';

  try {
    final managerDoc =
        await firestore.collection('users').doc(currentUser.uid).get();
    managerCode = (managerDoc.data()?['managerCode'] ?? '').toString().trim();
  } catch (_) {
    managerCode = '';
  }

  final linkedFarmerIds = <String>{currentUser.uid};
  final linkedFarmerEmails = <String>{};
  final currentEmail = (currentUser.email ?? '').trim();
  if (currentEmail.isNotEmpty) {
    linkedFarmerEmails.add(currentEmail);
  }

  try {
    final linkedFarmers = await firestore
        .collection('users')
        .where('farmManagerId', isEqualTo: currentUser.uid)
        .get();

    for (final farmer in linkedFarmers.docs) {
      linkedFarmerIds.add(farmer.id);
      final email = (farmer.data()['email'] ?? '').toString().trim();
      if (email.isNotEmpty) {
        linkedFarmerEmails.add(email);
      }
    }
  } catch (_) {
    // Leave the scope open when farmer linkage is unavailable.
  }

  return FarmManagerScope(
    managerUid: currentUser.uid,
    managerEmail: currentEmail,
    managerCode: managerCode,
    linkedFarmerIds: linkedFarmerIds,
    linkedFarmerEmails: linkedFarmerEmails,
  );
}

List<Map<String, dynamic>> buildScopedTrees(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> treeDocs,
  FarmManagerScope scope,
) {
  final trees = treeDocs
      .map(
        (doc) => <String, dynamic>{
          '_docId': doc.id,
          ...doc.data(),
        },
      )
      .toList(growable: false);

  if (!scope.hasLinkedFarmers) {
    return trees;
  }

  return trees.where((tree) => treeMatchesScope(tree, scope)).toList();
}

List<FarmManagerFarm> buildFarmSummaries({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> farmDocs,
  required List<Map<String, dynamic>> scopedTrees,
  required FarmManagerScope scope,
}) {
  if (farmDocs.isNotEmpty) {
    final farms = <FarmManagerFarm>[];
    for (final doc in farmDocs) {
      final data = doc.data();
      final relatedTrees = scopedTrees
          .where((tree) => _treeBelongsToFarmDoc(tree, doc.id, data))
          .toList(growable: false);

      if (scope.hasLinkedFarmers &&
          relatedTrees.isEmpty &&
          !farmMatchesScope(data, scope)) {
        continue;
      }

      farms.add(
        _farmFromDoc(
          doc.id,
          data,
          relatedTrees,
        ),
      );
    }

    if (farms.isNotEmpty) {
      farms.sort((left, right) => right.totalTrees.compareTo(left.totalTrees));
      return farms;
    }
  }

  return buildDerivedFarmSummaries(scopedTrees);
}

List<FarmManagerFarm> buildDerivedFarmSummaries(
  List<Map<String, dynamic>> scopedTrees,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};

  for (final tree in scopedTrees) {
    final farmId = farmIdFromTree(tree);
    grouped.putIfAbsent(farmId, () => <Map<String, dynamic>>[]).add(tree);
  }

  final farms = grouped.entries
      .map((entry) => _farmFromTrees(entry.key, entry.value))
      .toList(growable: false)
    ..sort((left, right) => right.totalTrees.compareTo(left.totalTrees));

  return farms;
}

List<FarmManagerIssue> buildIssueSummaries({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> issueDocs,
  required List<Map<String, dynamic>> scopedTrees,
  required FarmManagerScope scope,
}) {
  final issueMaps = issueDocs
      .map(
        (doc) => <String, dynamic>{
          '_docId': doc.id,
          ...doc.data(),
        },
      )
      .toList(growable: false);

  return buildIssueSummariesFromMaps(
    issueMaps: issueMaps,
    scopedTrees: scopedTrees,
    scope: scope,
  );
}

List<FarmManagerIssue> buildIssueSummariesFromMaps({
  required List<Map<String, dynamic>> issueMaps,
  required List<Map<String, dynamic>> scopedTrees,
  required FarmManagerScope scope,
}) {
  final treeByDocId = <String, Map<String, dynamic>>{
    for (final tree in scopedTrees)
      if ((tree['_docId'] ?? '').toString().trim().isNotEmpty)
        (tree['_docId'] ?? '').toString().trim(): tree,
  };

  final issues = <FarmManagerIssue>[];

  for (final data in issueMaps) {
    final treeDocId = (data['treeDocId'] ?? '').toString().trim();
    final relatedTree = treeByDocId[treeDocId];

    if (scope.hasLinkedFarmers &&
        !_issueMatchesScope(
          issue: data,
          relatedTree: relatedTree,
          scope: scope,
        )) {
      continue;
    }

    final health = healthLabel(
      data['healthStatus'] ?? relatedTree?['healthStatus'],
    );
    final status = normalizedIssueStatus(data['status']);
    final severity = issueSeverity(
      status: status,
      healthLabelValue: health,
    );
    final treeId = firstNonEmptyString(
      [
        data['treeId'],
        relatedTree?['treeId'],
      ],
      fallback: 'Unknown Tree',
    );
    final farmLabel = firstNonEmptyString(
      [
        relatedTree == null ? '' : farmNameFromTree(relatedTree),
        relatedTree?['location'],
        data['farm'],
        data['ownerName'],
      ],
      fallback: 'Unassigned Farm',
    );
    final ownerName = firstNonEmptyString(
      [
        data['ownerName'],
        relatedTree?['ownerName'],
        relatedTree?['farmerName'],
      ],
      fallback: 'Unknown Farmer',
    );
    final note = (data['note'] ?? '').toString().trim();
    final title = firstNonEmptyString(
      [
        data['title'],
        note.isEmpty ? '' : note,
        '$health reported on $treeId',
      ],
      fallback: 'Issue reported',
    );
    final hasImage = data['hasImage'] == true ||
        (data['imageUrl'] ?? '').toString().trim().isNotEmpty;

    issues.add(
      FarmManagerIssue(
        id: firstNonEmptyString(
          [
            data['_docId'],
            data['reportId'],
          ],
          fallback: treeDocId,
        ),
        treeDocId: treeDocId,
        treeId: treeId,
        farmId: relatedTree == null ? '' : farmIdFromTree(relatedTree),
        farmLabel: farmLabel,
        title: title,
        note: note,
        status: status,
        severity: severity,
        healthLabel: health,
        ownerName: ownerName,
        hasImage: hasImage,
        createdAt: parseDateTime(
          data['createdAt'] ??
              data['updatedAt'] ??
              data['createdAtLocal'] ??
              data['savedAt'],
        ),
      ),
    );
  }

  issues.sort((left, right) {
    final rightTime = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  });

  return issues;
}

List<FarmManagerIssue> buildDerivedIssuesFromTrees(
  List<Map<String, dynamic>> scopedTrees,
) {
  final issues = <FarmManagerIssue>[];

  for (final tree in scopedTrees) {
    final health = healthLabel(tree['healthStatus']);
    if (health == 'Healthy' || health == 'Unknown') {
      continue;
    }

    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    final treeId = firstNonEmptyString(
      [tree['treeId']],
      fallback: 'Unknown Tree',
    );
    final farmLabel = farmNameFromTree(tree);
    final ownerName = farmerNameFromTree(tree);
    final note = firstNonEmptyString(
      [
        tree['notes'],
        tree['healthStatusName'],
      ],
      fallback: 'No message',
    );
    final status = 'Open';

    issues.add(
      FarmManagerIssue(
        id: treeDocId.isEmpty ? treeId : 'derived_$treeDocId',
        treeDocId: treeDocId,
        treeId: treeId,
        farmId: farmIdFromTree(tree),
        farmLabel: farmLabel,
        title: '$health Alert',
        note: note,
        status: status,
        severity: issueSeverity(
          status: status,
          healthLabelValue: health,
        ),
        healthLabel: health,
        ownerName: ownerName,
        hasImage: false,
        createdAt: parseDateTime(
          tree['updatedAt'] ??
              tree['lastinspectiondate'] ??
              tree['lastInspectionDate'],
        ),
      ),
    );
  }

  issues.sort((left, right) {
    final rightTime = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  });

  return issues;
}

int uniqueFarmerCount(List<Map<String, dynamic>> trees) {
  final farmers = <String>{};
  for (final tree in trees) {
    final farmerId = firstNonEmptyString(
      [
        tree['userId'],
        tree['ownerId'],
        tree['farmerId'],
        tree['uid'],
      ],
    );
    final farmerName = farmerNameFromTree(tree);
    if (farmerId.isNotEmpty) {
      farmers.add(farmerId);
    } else if (farmerName.isNotEmpty) {
      farmers.add(farmerName.toLowerCase());
    }
  }
  return farmers.length;
}

bool treeMatchesScope(
  Map<String, dynamic> tree,
  FarmManagerScope scope,
) {
  if (!scope.hasLinkedFarmers) {
    return true;
  }

  final ownerId = firstNonEmptyString(
    [
      tree['userId'],
      tree['ownerId'],
      tree['farmerId'],
      tree['uid'],
      tree['createdBy'],
    ],
  );
  if (ownerId.isNotEmpty && scope.linkedFarmerIds.contains(ownerId)) {
    return true;
  }

  final ownerEmail = firstNonEmptyString(
    [
      tree['userEmail'],
      tree['email'],
      tree['ownerEmail'],
      tree['farmerEmail'],
    ],
  );
  if (ownerEmail.isNotEmpty && scope.linkedFarmerEmails.contains(ownerEmail)) {
    return true;
  }

  final managerId = firstNonEmptyString(
    [
      tree['farmManagerId'],
      tree['managerId'],
    ],
  );
  if (managerId.isNotEmpty && managerId == scope.managerUid) {
    return true;
  }

  final managerCode = firstNonEmptyString(
    [
      tree['farmManagerCode'],
      tree['managerCode'],
    ],
  );
  return managerCode.isNotEmpty &&
      scope.managerCode.isNotEmpty &&
      managerCode == scope.managerCode;
}

bool farmMatchesScope(
  Map<String, dynamic> farm,
  FarmManagerScope scope,
) {
  if (!scope.hasLinkedFarmers) {
    return true;
  }

  final farmOwnerId = firstNonEmptyString(
    [
      farm['userId'],
      farm['ownerId'],
      farm['farmerId'],
      farm['uid'],
      farm['assignedUserId'],
    ],
  );
  if (farmOwnerId.isNotEmpty && scope.linkedFarmerIds.contains(farmOwnerId)) {
    return true;
  }

  final farmOwnerEmail = firstNonEmptyString(
    [
      farm['email'],
      farm['ownerEmail'],
      farm['farmerEmail'],
      farm['userEmail'],
    ],
  );
  if (farmOwnerEmail.isNotEmpty &&
      scope.linkedFarmerEmails.contains(farmOwnerEmail)) {
    return true;
  }

  final managerId = firstNonEmptyString(
    [
      farm['farmManagerId'],
      farm['managerId'],
    ],
  );
  if (managerId.isNotEmpty && managerId == scope.managerUid) {
    return true;
  }

  final managerCode = firstNonEmptyString(
    [
      farm['farmManagerCode'],
      farm['managerCode'],
    ],
  );
  return managerCode.isNotEmpty &&
      scope.managerCode.isNotEmpty &&
      managerCode == scope.managerCode;
}

String farmIdFromTree(Map<String, dynamic> tree) {
  final explicitId = firstNonEmptyString(
    [
      tree['farmId'],
      tree['assignedFarmId'],
    ],
  );
  if (explicitId.isNotEmpty) {
    return explicitId;
  }

  final raw = [
    farmNameFromTree(tree),
    firstNonEmptyString([tree['location']], fallback: 'location'),
    firstNonEmptyString(
      [
        tree['userId'],
        tree['ownerId'],
        tree['farmerId'],
        tree['ownerName'],
        tree['farmerName'],
      ],
      fallback: 'owner',
    ),
  ].join('|').toLowerCase();

  return raw.replaceAll(RegExp(r'[^a-z0-9|]+'), '_');
}

String farmNameFromTree(Map<String, dynamic> tree) {
  return firstNonEmptyString(
    [
      tree['farmName'],
      tree['farm'],
      tree['location'],
      tree['ownerName'],
      tree['farmerName'],
    ],
    fallback: 'Farm',
  );
}

String farmerNameFromTree(Map<String, dynamic> tree) {
  return firstNonEmptyString(
    [
      tree['ownerName'],
      tree['farmerName'],
      tree['userName'],
    ],
    fallback: 'Farmer',
  );
}

String firstNonEmptyString(
  List<dynamic> values, {
  String fallback = '',
}) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return fallback;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

double asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

double? asNullableDouble(dynamic value) {
  if (value == null) return null;
  final parsed = asDouble(value);
  return parsed == 0 ? null : parsed;
}

DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is Map && value['_seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      asInt(value['_seconds']) * 1000,
    );
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String healthLabel(dynamic rawStatus) {
  final normalized = (rawStatus ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case '0':
    case 'healthy':
      return 'Healthy';
    case '1':
    case 'needsattention':
    case 'needs attention':
      return 'Needs Attention';
    case '2':
    case 'atrisk':
    case 'at risk':
      return 'At Risk';
    case '3':
    case 'sick':
    case 'diseased':
      return 'Critical';
    default:
      return 'Unknown';
  }
}

Color healthColor(String label) {
  switch (label.toLowerCase()) {
    case 'healthy':
      return Colors.green;
    case 'needs attention':
      return Colors.orange;
    case 'at risk':
    case 'critical':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

String normalizedIssueStatus(dynamic rawStatus) {
  final normalized = (rawStatus ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'resolved':
    case 'closed':
      return 'Resolved';
    case 'critical':
      return 'Critical';
    case 'in progress':
    case 'in_progress':
      return 'In Progress';
    case 'open':
      return 'Open';
    default:
      return normalized.isEmpty ? 'Open' : _toTitleCase(normalized);
  }
}

String issueSeverity({
  required String status,
  required String healthLabelValue,
}) {
  final normalizedStatus = status.trim().toLowerCase();
  if (normalizedStatus == 'resolved' || normalizedStatus == 'closed') {
    return 'Resolved';
  }
  if (normalizedStatus == 'critical') {
    return 'Critical';
  }

  switch (healthLabelValue.toLowerCase()) {
    case 'critical':
    case 'at risk':
      return 'Critical';
    case 'needs attention':
      return 'Monitoring';
    case 'healthy':
      return 'Open';
    default:
      return 'Open';
  }
}

Color issueSeverityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'resolved':
      return Colors.green;
    case 'critical':
      return Colors.red;
    case 'monitoring':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}

String issueStatusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'critical') {
    return 'Needs Attention';
  }
  return status;
}

String initialsFor(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return 'FM';
  return parts.map((part) => part[0].toUpperCase()).join();
}

FarmManagerFarm _farmFromDoc(
  String id,
  Map<String, dynamic> data,
  List<Map<String, dynamic>> relatedTrees,
) {
  final derived = _farmMetricsFromTrees(relatedTrees);

  return FarmManagerFarm(
    id: id,
    name: firstNonEmptyString(
      [
        data['name'],
        data['farmName'],
      ],
      fallback: 'Farm',
    ),
    location: firstNonEmptyString(
      [
        data['location'],
        data['address'],
        data['village'],
      ],
      fallback: 'Location unavailable',
    ),
    totalTrees: asInt(data['treesCount']) > 0
        ? asInt(data['treesCount'])
        : derived.totalTrees,
    healthyTrees: derived.healthyTrees,
    needsAttentionTrees: derived.needsAttentionTrees,
    atRiskTrees: derived.atRiskTrees,
    scannedTrees: derived.scannedTrees,
    areaAcres: asDouble(
      data['area'] ?? data['areaAcres'] ?? data['landSize'] ?? 0,
    ),
    farmerName: firstNonEmptyString(
      [
        data['farmerName'],
        data['ownerName'],
        data['assignedUserName'],
      ],
      fallback: derived.farmerName,
    ),
    farmerPhone: firstNonEmptyString(
      [
        data['farmerPhone'],
        data['phone'],
        data['mobile'],
      ],
    ),
    farmerEmail: firstNonEmptyString(
      [
        data['farmerEmail'],
        data['email'],
      ],
    ),
    latitude: asNullableDouble(data['latitude']) ?? derived.latitude,
    longitude: asNullableDouble(data['longitude']) ?? derived.longitude,
    trees: relatedTrees,
  );
}

FarmManagerFarm _farmFromTrees(
  String farmId,
  List<Map<String, dynamic>> trees,
) {
  final metrics = _farmMetricsFromTrees(trees);

  return FarmManagerFarm(
    id: farmId,
    name: farmNameFromTree(trees.first),
    location: firstNonEmptyString(
      [
        trees.first['location'],
        trees.first['plotNumber'],
        trees.first['plot'],
      ],
      fallback: 'Location unavailable',
    ),
    totalTrees: metrics.totalTrees,
    healthyTrees: metrics.healthyTrees,
    needsAttentionTrees: metrics.needsAttentionTrees,
    atRiskTrees: metrics.atRiskTrees,
    scannedTrees: metrics.scannedTrees,
    areaAcres: 0,
    farmerName: metrics.farmerName,
    farmerPhone: firstNonEmptyString(
      trees.map((tree) => tree['phone']).toList(growable: false),
    ),
    farmerEmail: firstNonEmptyString(
      trees.map((tree) => tree['userEmail']).toList(growable: false),
    ),
    latitude: metrics.latitude,
    longitude: metrics.longitude,
    trees: trees,
  );
}

({
  int totalTrees,
  int healthyTrees,
  int needsAttentionTrees,
  int atRiskTrees,
  int scannedTrees,
  String farmerName,
  double? latitude,
  double? longitude,
}) _farmMetricsFromTrees(List<Map<String, dynamic>> trees) {
  var healthyTrees = 0;
  var needsAttentionTrees = 0;
  var atRiskTrees = 0;
  var scannedTrees = 0;
  final latitudes = <double>[];
  final longitudes = <double>[];

  for (final tree in trees) {
    final health = healthLabel(tree['healthStatus']);
    switch (health) {
      case 'Healthy':
        healthyTrees++;
      case 'Needs Attention':
        needsAttentionTrees++;
      case 'At Risk':
      case 'Critical':
        atRiskTrees++;
      default:
        break;
    }

    if (tree['isScanned'] == true) {
      scannedTrees++;
    }

    final latitude = asNullableDouble(tree['latitude']);
    final longitude = asNullableDouble(tree['longitude']);
    if (latitude != null && longitude != null) {
      latitudes.add(latitude);
      longitudes.add(longitude);
    }
  }

  return (
    totalTrees: trees.length,
    healthyTrees: healthyTrees,
    needsAttentionTrees: needsAttentionTrees,
    atRiskTrees: atRiskTrees,
    scannedTrees: scannedTrees,
    farmerName: trees.isEmpty ? 'Farmer' : farmerNameFromTree(trees.first),
    latitude: latitudes.isEmpty
        ? null
        : latitudes.reduce((a, b) => a + b) / latitudes.length,
    longitude: longitudes.isEmpty
        ? null
        : longitudes.reduce((a, b) => a + b) / longitudes.length,
  );
}

bool _issueMatchesScope({
  required Map<String, dynamic> issue,
  required Map<String, dynamic>? relatedTree,
  required FarmManagerScope scope,
}) {
  if (relatedTree != null && treeMatchesScope(relatedTree, scope)) {
    return true;
  }

  final reporterId = firstNonEmptyString(
    [
      issue['reportedByUid'],
      issue['userId'],
    ],
  );
  if (reporterId.isNotEmpty && scope.linkedFarmerIds.contains(reporterId)) {
    return true;
  }

  final reporterEmail = firstNonEmptyString(
    [
      issue['reportedByEmail'],
      issue['userEmail'],
    ],
  );
  return reporterEmail.isNotEmpty &&
      scope.linkedFarmerEmails.contains(reporterEmail);
}

bool _treeBelongsToFarmDoc(
  Map<String, dynamic> tree,
  String farmDocId,
  Map<String, dynamic> farm,
) {
  final treeFarmId = firstNonEmptyString(
    [
      tree['farmId'],
      tree['assignedFarmId'],
    ],
  );
  if (treeFarmId.isNotEmpty && treeFarmId == farmDocId) {
    return true;
  }

  final farmName = firstNonEmptyString(
    [
      farm['name'],
      farm['farmName'],
    ],
  ).toLowerCase();
  final treeFarmName = firstNonEmptyString(
    [
      tree['farmName'],
      tree['farm'],
    ],
  ).toLowerCase();
  if (farmName.isNotEmpty &&
      treeFarmName.isNotEmpty &&
      farmName == treeFarmName) {
    return true;
  }

  final farmLocation = firstNonEmptyString(
    [
      farm['location'],
      farm['address'],
      farm['village'],
    ],
  ).toLowerCase();
  final treeLocation = firstNonEmptyString(
    [
      tree['location'],
      tree['plotNumber'],
      tree['plot'],
    ],
  ).toLowerCase();
  return farmLocation.isNotEmpty &&
      treeLocation.isNotEmpty &&
      farmLocation == treeLocation;
}

String _toTitleCase(String value) {
  return value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

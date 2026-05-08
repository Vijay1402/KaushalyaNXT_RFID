import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'admin_management_forms.dart';

class AdminManagementService {
  AdminManagementService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createFarm(AdminFarmFormData data) async {
    final docRef = _firestore.collection('farms').doc();
    await docRef.set(
      _buildFarmPayload(
        data,
        includeCreatedAt: true,
      ),
      SetOptions(merge: true),
    );
    return docRef.id;
  }

  Future<void> updateFarm({
    required String farmId,
    required AdminFarmFormData data,
    required List<String> linkedTreeDocIds,
  }) async {
    final docRef = _firestore.collection('farms').doc(farmId);
    await docRef.set(
      _buildFarmPayload(data),
      SetOptions(merge: true),
    );

    if (linkedTreeDocIds.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final treeDocId in linkedTreeDocIds) {
      final trimmedId = treeDocId.trim();
      if (trimmedId.isEmpty) {
        continue;
      }

      batch.set(
        _firestore.collection('trees').doc(trimmedId),
        {
          'farmId': farmId,
          'farmName': data.name,
          'ownerName': data.farmerName,
          'farmerName': data.farmerName,
          'farmerEmail': data.farmerEmail,
          'ownerEmail': data.farmerEmail,
          'farmerId': data.farmerId,
          'userId': data.farmerId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> deleteFarm({
    required String farmId,
    required List<String> treeDocIds,
  }) async {
    for (final treeDocId in treeDocIds) {
      final trimmedId = treeDocId.trim();
      if (trimmedId.isEmpty) {
        continue;
      }
      await deleteTree(treeDocId: trimmedId, farmId: farmId);
    }

    await _firestore.collection('farms').doc(farmId).delete();
  }

  Future<String> createTree({
    required String farmId,
    required String farmName,
    required String farmerName,
    required String farmerId,
    required String farmerEmail,
    required AdminTreeFormData data,
  }) async {
    final trimmedFarmId = farmId.trim();
    if (trimmedFarmId.isEmpty) {
      throw StateError(
        'The selected farm is missing a valid Firestore id. '
        'Please reopen the farm and try again.',
      );
    }

    final trimmedTreeId = data.treeId.trim();
    if (trimmedTreeId.isEmpty) {
      throw StateError('Tree ID is required.');
    }

    final docRef = _firestore.collection('trees').doc();
    final farmRef = _firestore.collection('farms').doc(trimmedFarmId);
    final farmData = await _safeFarmData(farmRef);
    final resolvedFarmerName = _firstNonEmptyString(
      [
        data.farmerName,
        farmerName,
        farmData['farmerName'],
        farmData['ownerName'],
      ],
      fallback: 'Farmer',
    );
    final resolvedFarmerId = _firstNonEmptyString(
      [
        farmerId,
        farmData['farmerId'],
        farmData['userId'],
        farmData['ownerId'],
        farmData['assignedUserId'],
      ],
    );
    final resolvedFarmerEmail = _firstNonEmptyString(
      [
        farmerEmail,
        farmData['farmerEmail'],
        farmData['userEmail'],
        farmData['ownerEmail'],
        farmData['email'],
      ],
    );
    final treePayload = _buildTreePayload(
      farmId: trimmedFarmId,
      farmName: farmName,
      farmerName: resolvedFarmerName,
      farmerId: resolvedFarmerId,
      farmerEmail: resolvedFarmerEmail,
      data: data,
      includeCreatedAt: true,
      farmData: farmData,
    );

    final batch = _firestore.batch();
    batch.set(docRef, treePayload, SetOptions(merge: true));
    batch.set(
      farmRef,
      _buildFarmTreeCounterPayload(
        farmId: trimmedFarmId,
        farmName: farmName,
        farmerName: resolvedFarmerName,
        farmerId: resolvedFarmerId,
        farmerEmail: resolvedFarmerEmail,
        farmData: farmData,
      ),
      SetOptions(merge: true),
    );
    await batch.commit();

    return docRef.id;
  }

  Future<void> updateTree({
    required String treeDocId,
    required String farmId,
    required String farmName,
    required String farmerName,
    required String farmerId,
    required String farmerEmail,
    required AdminTreeFormData data,
  }) async {
    final trimmedTreeDocId = treeDocId.trim();
    if (trimmedTreeDocId.isEmpty) {
      throw StateError('This tree is missing a valid Firestore id.');
    }

    await _firestore.collection('trees').doc(trimmedTreeDocId).set(
          _buildTreePayload(
            farmId: farmId.trim(),
            farmName: farmName,
            farmerName: farmerName,
            farmerId: farmerId,
            farmerEmail: farmerEmail,
            data: data,
          ),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteTree({
    required String treeDocId,
    String? farmId,
  }) async {
    await _deleteTreeIssues(treeDocId);
    await _firestore.collection('trees').doc(treeDocId).delete();

    if (farmId != null && farmId.trim().isNotEmpty) {
      await _firestore.collection('farms').doc(farmId).set(
        {
          'treesCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Map<String, dynamic> _buildFarmPayload(
    AdminFarmFormData data, {
    bool includeCreatedAt = false,
  }) {
    final payload = <String, dynamic>{
      'name': data.name,
      'farmName': data.name,
      'location': data.location,
      'address': data.location,
      'area': data.areaAcres,
      'areaAcres': data.areaAcres,
      'farmerName': data.farmerName,
      'farmerPhone': data.farmerPhone,
      'phone': data.farmerPhone,
      'farmerEmail': data.farmerEmail,
      'email': data.farmerEmail,
      'farmerId': data.farmerId,
      'userId': data.farmerId,
      'assignedUserId': data.farmerId,
      'assignedfarmerId': data.farmerId,
      'managerId': data.managerId,
      'farmManagerId': data.managerId,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    return payload;
  }

  Map<String, dynamic> _buildTreePayload({
    required String farmId,
    required String farmName,
    required String farmerName,
    required String farmerId,
    required String farmerEmail,
    required AdminTreeFormData data,
    bool includeCreatedAt = false,
    Map<String, dynamic> farmData = const <String, dynamic>{},
  }) {
    final resolvedFarmerName = _firstNonEmptyString(
      [
        data.farmerName,
        farmerName,
        farmData['farmerName'],
        farmData['ownerName'],
      ],
      fallback: 'Farmer',
    );
    final resolvedFarmerId = _firstNonEmptyString(
      [
        farmerId,
        farmData['farmerId'],
        farmData['userId'],
        farmData['ownerId'],
        farmData['assignedUserId'],
      ],
    );
    final resolvedFarmerEmail = _firstNonEmptyString(
      [
        farmerEmail,
        farmData['farmerEmail'],
        farmData['userEmail'],
        farmData['ownerEmail'],
        farmData['email'],
      ],
    );
    final managerId = _firstNonEmptyString(
      [
        farmData['farmManagerId'],
        farmData['managerId'],
      ],
    );
    final managerCode = _firstNonEmptyString(
      [
        farmData['farmManagerCode'],
        farmData['managerCode'],
      ],
    );
    final managerName = _firstNonEmptyString(
      [
        farmData['farmManagerName'],
      ],
    );
    final normalizedRfid = data.rfid.trim();
    final normalizedTreeId = data.treeId.trim();
    final normalizedFarmName = farmName.trim().isEmpty
        ? _firstNonEmptyString([farmData['name'], farmData['farmName']])
        : farmName.trim();
    final normalizedLocation = data.location.trim();
    final normalizedSpecies =
        data.species.trim().isEmpty ? 'Unknown' : data.species.trim();
    final scanned = data.isScanned || normalizedRfid.isNotEmpty;
    final payload = <String, dynamic>{
      'treeId': normalizedTreeId,
      'species': normalizedSpecies,
      'speciesCode': _speciesCodeFromLabel(normalizedSpecies),
      'location': normalizedLocation,
      'farmId': farmId,
      'assignedFarmId': farmId,
      'farmName': normalizedFarmName,
      'farm': normalizedFarmName,
      'ownerName': resolvedFarmerName,
      'farmerName': resolvedFarmerName,
      'ownerId': resolvedFarmerId,
      'farmerId': resolvedFarmerId,
      'userId': resolvedFarmerId,
      'assignedUserId': resolvedFarmerId,
      'userEmail': resolvedFarmerEmail,
      'email': resolvedFarmerEmail,
      'farmerEmail': resolvedFarmerEmail,
      'ownerEmail': resolvedFarmerEmail,
      'healthStatus': data.healthStatus,
      'healthStatusName': _healthStatusNameFromCode(data.healthStatus),
      'treeAge': data.ageYears,
      'age': data.ageYears,
      'lastYieldKg': data.lastYieldKg,
      'yieldKg': data.lastYieldKg,
      'harvestMonth': data.harvestMonth,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'rfid': normalizedRfid,
      'rfidTag': normalizedRfid,
      'isScanned': scanned,
      'lastinspectiondate': FieldValue.serverTimestamp(),
      'lastInspectionDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (managerId.isNotEmpty) {
      payload['managerId'] = managerId;
      payload['farmManagerId'] = managerId;
    }
    if (managerCode.isNotEmpty) {
      payload['managerCode'] = managerCode;
      payload['farmManagerCode'] = managerCode;
    }
    if (managerName.isNotEmpty) {
      payload['farmManagerName'] = managerName;
    }
    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    return payload;
  }

  Map<String, dynamic> _buildFarmTreeCounterPayload({
    required String farmId,
    required String farmName,
    required String farmerName,
    required String farmerId,
    required String farmerEmail,
    required Map<String, dynamic> farmData,
  }) {
    final payload = <String, dynamic>{
      'treesCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final resolvedFarmName = _firstNonEmptyString(
      [
        farmName,
        farmData['name'],
        farmData['farmName'],
      ],
    );
    if (resolvedFarmName.isNotEmpty) {
      payload['name'] = resolvedFarmName;
      payload['farmName'] = resolvedFarmName;
    }

    final resolvedFarmerName = _firstNonEmptyString(
      [
        farmerName,
        farmData['farmerName'],
        farmData['ownerName'],
      ],
    );
    if (resolvedFarmerName.isNotEmpty) {
      payload['farmerName'] = resolvedFarmerName;
    }

    final resolvedFarmerId = _firstNonEmptyString(
      [
        farmerId,
        farmData['farmerId'],
        farmData['userId'],
        farmData['ownerId'],
        farmData['assignedUserId'],
      ],
    );
    if (resolvedFarmerId.isNotEmpty) {
      payload['farmerId'] = resolvedFarmerId;
      payload['userId'] = resolvedFarmerId;
      payload['assignedUserId'] = resolvedFarmerId;
    }

    final resolvedFarmerEmail = _firstNonEmptyString(
      [
        farmerEmail,
        farmData['farmerEmail'],
        farmData['userEmail'],
        farmData['ownerEmail'],
        farmData['email'],
      ],
    );
    if (resolvedFarmerEmail.isNotEmpty) {
      payload['farmerEmail'] = resolvedFarmerEmail;
      payload['email'] = resolvedFarmerEmail;
      payload['userEmail'] = resolvedFarmerEmail;
      payload['ownerEmail'] = resolvedFarmerEmail;
    }

    final managerId = _firstNonEmptyString(
      [
        farmData['farmManagerId'],
        farmData['managerId'],
      ],
    );
    if (managerId.isNotEmpty) {
      payload['managerId'] = managerId;
      payload['farmManagerId'] = managerId;
    }

    final managerCode = _firstNonEmptyString(
      [
        farmData['farmManagerCode'],
        farmData['managerCode'],
      ],
    );
    if (managerCode.isNotEmpty) {
      payload['managerCode'] = managerCode;
      payload['farmManagerCode'] = managerCode;
    }

    final managerName = _firstNonEmptyString(
      [
        farmData['farmManagerName'],
      ],
    );
    if (managerName.isNotEmpty) {
      payload['farmManagerName'] = managerName;
    }

    final location = _firstNonEmptyString(
      [
        farmData['location'],
        farmData['address'],
        farmData['village'],
      ],
    );
    if (location.isNotEmpty) {
      payload['location'] = location;
      payload['address'] = location;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _safeFarmData(
    DocumentReference<Map<String, dynamic>> farmRef,
  ) async {
    try {
      final snapshot = await farmRef.get();
      return snapshot.data() ?? const <String, dynamic>{};
    } on FirebaseException {
      return const <String, dynamic>{};
    }
  }

  String _healthStatusNameFromCode(String rawStatus) {
    switch (rawStatus.trim()) {
      case '1':
        return 'Needs Attention';
      case '2':
        return 'At Risk';
      case '3':
        return 'Critical';
      default:
        return 'Healthy';
    }
  }

  String _speciesCodeFromLabel(String rawSpecies) {
    switch (rawSpecies.trim().toLowerCase()) {
      case 'mango':
        return 'mango';
      case 'coconut':
        return 'coconut';
      case 'arecanut':
        return 'arecanut';
      case 'cashew':
        return 'cashew';
      default:
        return rawSpecies.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  String _firstNonEmptyString(
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

  Future<void> _deleteTreeIssues(String treeDocId) async {
    final issueCollection =
        _firestore.collection('trees').doc(treeDocId).collection('issues');
    final snapshot = await issueCollection.get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final issueDoc in snapshot.docs) {
      batch.delete(issueDoc.reference);
    }
    await batch.commit();
  }
}

final adminManagementServiceProvider = Provider<AdminManagementService>((ref) {
  return AdminManagementService(
    firestore: ref.read(firestoreProvider),
  );
});

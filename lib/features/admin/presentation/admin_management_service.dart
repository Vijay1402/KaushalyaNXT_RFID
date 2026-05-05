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
    final docRef = _firestore.collection('trees').doc();
    await docRef.set(
      _buildTreePayload(
        farmId: farmId,
        farmName: farmName,
        farmerName: farmerName,
        farmerId: farmerId,
        farmerEmail: farmerEmail,
        data: data,
        includeCreatedAt: true,
      ),
      SetOptions(merge: true),
    );

    await _firestore.collection('farms').doc(farmId).set(
      {
        'treesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

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
    await _firestore.collection('trees').doc(treeDocId).set(
          _buildTreePayload(
            farmId: farmId,
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
  }) {
    final payload = <String, dynamic>{
      'treeId': data.treeId,
      'species': data.species,
      'location': data.location,
      'farmId': farmId,
      'farmName': farmName,
      'ownerName': data.farmerName.isEmpty ? farmerName : data.farmerName,
      'farmerName': data.farmerName.isEmpty ? farmerName : data.farmerName,
      'farmerId': farmerId,
      'userId': farmerId,
      'farmerEmail': farmerEmail,
      'ownerEmail': farmerEmail,
      'healthStatus': data.healthStatus,
      'treeAge': data.ageYears,
      'age': data.ageYears,
      'lastYieldKg': data.lastYieldKg,
      'yieldKg': data.lastYieldKg,
      'harvestMonth': data.harvestMonth,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'rfid': data.rfid,
      'isScanned': data.isScanned,
      'lastinspectiondate': FieldValue.serverTimestamp(),
      'lastInspectionDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    return payload;
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

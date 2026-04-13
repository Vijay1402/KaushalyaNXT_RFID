import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_model.dart';

class LocalCacheService {
  static const String _cachedUserKey = 'cached_user';
  static const String _treeCachePrefix = 'cached_trees_';
  static const String _writtenTagPrefix = 'written_tag_';
  static const String _pendingTreeSyncPrefix = 'pending_tree_sync_';
  static const String _pendingIssuePrefix = 'pending_issues_';
  static const String _issueHistoryPrefix = 'issue_history_';

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cachedUserKey,
      jsonEncode({
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'phone': user.phone,
      }),
    );
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel(
        name: (data['name'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        role: (data['role'] ?? 'farmer').toString(),
        phone: (data['phone'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }

  Future<void> saveTrees(
      String userId, List<Map<String, dynamic>> trees) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_treeCachePrefix$userId',
      jsonEncode(_sanitizeValue(trees)),
    );
  }

  Future<List<Map<String, dynamic>>> getTrees(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_treeCachePrefix$userId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTree(String userId, Map<String, dynamic> tree) async {
    final docId = (tree['_docId'] ?? '').toString();
    if (docId.isEmpty) return;

    final trees = await getTrees(userId);
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in trees) {
      if ((item['_docId'] ?? '').toString() == docId) {
        updated.add(tree);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(tree);
    }

    await saveTrees(userId, updated);
  }

  Future<Map<String, dynamic>?> getTreeByDocId(
      String userId, String docId) async {
    final trees = await getTrees(userId);
    for (final tree in trees) {
      if ((tree['_docId'] ?? '').toString() == docId) {
        return tree;
      }
    }
    return null;
  }

  Future<String?> findTreeDocIdByTreeId(String userId, String treeId) async {
    final normalized = treeId.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final trees = await getTrees(userId);
    for (final tree in trees) {
      final currentTreeId =
          (tree['treeId'] ?? '').toString().trim().toLowerCase();
      if (currentTreeId == normalized) {
        final docId = (tree['_docId'] ?? '').toString();
        if (docId.isNotEmpty) return docId;
      }
    }
    return null;
  }

  Future<void> clearTrees(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_treeCachePrefix$userId');
  }

  Future<void> saveWrittenTag(
    String userId,
    Map<String, dynamic> tagData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final epc = (tagData['epc'] ?? '').toString().trim().toUpperCase();
    if (epc.isEmpty) return;

    await prefs.setString(
      '$_writtenTagPrefix$userId\_$epc',
      jsonEncode(_sanitizeValue(tagData)),
    );
  }

  Future<Map<String, dynamic>?> getWrittenTagByEpc(
    String userId,
    String epc,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_writtenTagPrefix$userId\_${epc.trim().toUpperCase()}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWrittenTagByTreeId(
    String userId,
    String treeId,
  ) async {
    final normalized = treeId.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('$_writtenTagPrefix$userId\_')) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final data = decoded.map(
          (innerKey, value) => MapEntry(innerKey.toString(), value),
        );
        final currentTreeId =
            (data['treeId'] ?? '').toString().trim().toLowerCase();
        if (currentTreeId == normalized) {
          return data;
        }
      } catch (_) {
        // Ignore malformed local entries.
      }
    }

    return null;
  }

  Future<void> clearWrittenTags(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('$_writtenTagPrefix$userId\_'))
        .toList(growable: false);

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> enqueuePendingTreeSync(
    String userId,
    Map<String, dynamic> tree,
  ) async {
    final docId = (tree['_docId'] ?? '').toString();
    if (docId.isEmpty) return;

    final pending = await getPendingTreeSyncs(userId);
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in pending) {
      if ((item['_docId'] ?? '').toString() == docId) {
        updated.add(tree);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(tree);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_pendingTreeSyncPrefix$userId',
      jsonEncode(_sanitizeValue(updated)),
    );
  }

  Future<List<Map<String, dynamic>>> getPendingTreeSyncs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_pendingTreeSyncPrefix$userId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> removePendingTreeSync(String userId, String docId) async {
    final pending = await getPendingTreeSyncs(userId);
    final updated = pending
        .where((item) => (item['_docId'] ?? '').toString() != docId)
        .toList(growable: false);

    final prefs = await SharedPreferences.getInstance();
    if (updated.isEmpty) {
      await prefs.remove('$_pendingTreeSyncPrefix$userId');
      return;
    }

    await prefs.setString(
      '$_pendingTreeSyncPrefix$userId',
      jsonEncode(_sanitizeValue(updated)),
    );
  }

  Future<void> clearPendingTreeSyncs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_pendingTreeSyncPrefix$userId');
  }

  Future<void> savePendingIssue(
    String userId,
    Map<String, dynamic> issueData,
  ) async {
    final reportId = (issueData['reportId'] ?? '').toString().trim();
    if (reportId.isEmpty) return;

    final issues = await getPendingIssues(userId);
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in issues) {
      if ((item['reportId'] ?? '').toString() == reportId) {
        updated.add(issueData);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(issueData);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_pendingIssuePrefix$userId',
      jsonEncode(_sanitizeValue(updated)),
    );
  }

  Future<List<Map<String, dynamic>>> getPendingIssues(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_pendingIssuePrefix$userId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> removePendingIssue(String userId, String reportId) async {
    final issues = await getPendingIssues(userId);
    final updated = issues
        .where((issue) => (issue['reportId'] ?? '').toString() != reportId)
        .toList(growable: false);

    final prefs = await SharedPreferences.getInstance();
    if (updated.isEmpty) {
      await prefs.remove('$_pendingIssuePrefix$userId');
      return;
    }

    await prefs.setString(
      '$_pendingIssuePrefix$userId',
      jsonEncode(_sanitizeValue(updated)),
    );
  }

  Future<void> clearPendingIssues(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_pendingIssuePrefix$userId');
  }

  Future<void> saveIssueHistoryEntry(
    String userId,
    Map<String, dynamic> issueData,
  ) async {
    final reportId = (issueData['reportId'] ?? '').toString().trim();
    if (reportId.isEmpty) return;

    final history = await getIssueHistory(userId);
    final updated = <Map<String, dynamic>>[];
    var replaced = false;

    for (final item in history) {
      if ((item['reportId'] ?? '').toString() == reportId) {
        updated.add(issueData);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(issueData);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_issueHistoryPrefix$userId',
      jsonEncode(_sanitizeValue(updated)),
    );
  }

  Future<List<Map<String, dynamic>>> getIssueHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_issueHistoryPrefix$userId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getIssueHistoryForTree(
    String userId,
    String treeDocId,
  ) async {
    final history = await getIssueHistory(userId);
    return history.where((item) {
      return (item['treeDocId'] ?? '').toString().trim() == treeDocId.trim();
    }).toList(growable: false);
  }

  Future<void> clearIssueHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_issueHistoryPrefix$userId');
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '_seconds': value.seconds,
        '_nanoseconds': value.nanoseconds,
      };
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      return value.map(
        (key, innerValue) => MapEntry(
          key.toString(),
          _sanitizeValue(innerValue),
        ),
      );
    }

    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }

    return value;
  }
}

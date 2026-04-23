import 'package:hive/hive.dart';

class ListingDraftStorage {
  static const String _boxName = 'listing_drafts_v1';
  static const int maxPendingDrafts = 5;

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return Hive.openBox<dynamic>(_boxName);
  }

  String _draftKeyForUser(String userId) {
    final normalized = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return 'draft_$normalized';
  }

  Future<void> saveDraft({
    required String userId,
    required String title,
    required String description,
    required String price,
    required String condition,
    required String exchangeType,
    required List<String> tags,
    required String tagsInput,
    required List<String> imagePaths,
  }) async {
    final box = await _box();
    final key = _draftKeyForUser(userId);
    final now = DateTime.now().toUtc().toIso8601String();

    await box.put(key, {
      'userId': userId,
      'title': title,
      'description': description,
      'price': price,
      'condition': condition,
      'exchangeType': exchangeType,
      'tags': tags,
      'tagsInput': tagsInput,
      'imagePaths': imagePaths,
      'status': 'pending',
      'updatedAt': now,
    });

    await _enforcePendingLimit(box);
  }

  Future<Map<String, dynamic>?> loadDraft(String userId) async {
    final box = await _box();
    final key = _draftKeyForUser(userId);
    final raw = box.get(key);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
  }

  Future<void> clearDraft(String userId) async {
    final box = await _box();
    await box.delete(_draftKeyForUser(userId));
  }

  Future<void> _enforcePendingLimit(Box<dynamic> box) async {
    final entries = <MapEntry<dynamic, dynamic>>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map && value['status'] == 'pending') {
        entries.add(MapEntry(key, value));
      }
    }

    if (entries.length <= maxPendingDrafts) return;

    entries.sort((a, b) {
      final aUpdated = (a.value['updatedAt'] as String?) ?? '';
      final bUpdated = (b.value['updatedAt'] as String?) ?? '';
      return aUpdated.compareTo(bUpdated);
    });

    final overflow = entries.length - maxPendingDrafts;
    for (int i = 0; i < overflow; i++) {
      await box.delete(entries[i].key);
    }
  }
}
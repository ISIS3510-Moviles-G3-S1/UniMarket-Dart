import 'package:hive/hive.dart';

class TradeDraftsBox {
  TradeDraftsBox._();
  static final TradeDraftsBox instance = TradeDraftsBox._();

  static const String _boxName = 'trade_drafts_v1';
  Box<dynamic>? _boxCache;

  Future<Box<dynamic>> _openBox() async {
    if (_boxCache != null) return _boxCache!;
    if (Hive.isBoxOpen(_boxName)) {
      _boxCache = Hive.box<dynamic>(_boxName);
    } else {
      _boxCache = await Hive.openBox<dynamic>(_boxName);
    }
    return _boxCache!;
  }

  String _key({required String userId, required String desiredListingId}) {
    return '${userId}_$desiredListingId';
  }

  Future<void> saveDraft({
    required String userId,
    required String desiredListingId,
    required String offeredListingId,
    required String message,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, desiredListingId: desiredListingId);
    await box.put(key, {
      'offeredListingId': offeredListingId,
      'message': message,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getDraft({
    required String userId,
    required String desiredListingId,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, desiredListingId: desiredListingId);
    final raw = box.get(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
  }

  Future<void> clearDraft({
    required String userId,
    required String desiredListingId,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, desiredListingId: desiredListingId);
    await box.delete(key);
  }
}

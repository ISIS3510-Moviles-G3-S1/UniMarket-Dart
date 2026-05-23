import 'package:hive/hive.dart';

class DonationDraftsBox {
  DonationDraftsBox._();
  static final DonationDraftsBox instance = DonationDraftsBox._();

  static const String _boxName = 'donation_drafts_v1';
  Box<String>? _boxCache;

  Future<Box<String>> _openBox() async {
    if (_boxCache != null) return _boxCache!;
    if (Hive.isBoxOpen(_boxName)) {
      _boxCache = Hive.box<String>(_boxName);
    } else {
      _boxCache = await Hive.openBox<String>(_boxName);
    }
    return _boxCache!;
  }

  String _key({required String userId, required String listingId}) {
    return '${userId}_$listingId';
  }

  Future<void> saveDraft({
    required String userId,
    required String listingId,
    required String text,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, listingId: listingId);
    if (text.trim().isEmpty) {
      await box.delete(key);
      return;
    }
    await box.put(key, text);
  }

  Future<String> getDraft({
    required String userId,
    required String listingId,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, listingId: listingId);
    return box.get(key, defaultValue: '') ?? '';
  }

  Future<void> clearDraft({
    required String userId,
    required String listingId,
  }) async {
    final box = await _openBox();
    final key = _key(userId: userId, listingId: listingId);
    await box.delete(key);
  }
}

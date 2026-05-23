import 'dart:collection';
import '../models/app_user.dart';

class _CacheEntry {
  final AppUser user;
  final DateTime expiresAt;

  _CacheEntry(this.user, this.expiresAt);
}

class DonationRequesterProfileCache {
  DonationRequesterProfileCache._();
  static final DonationRequesterProfileCache instance = DonationRequesterProfileCache._();

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap<String, _CacheEntry>();
  final int capacity = 100;
  final Duration ttl = const Duration(seconds: 600);

  void put(String uid, AppUser user) {
    if (_cache.containsKey(uid)) {
      _cache.remove(uid);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // evict least recently used (first inserted in LinkedHashMap)
    }
    _cache[uid] = _CacheEntry(user, DateTime.now().add(ttl));
  }

  AppUser? get(String uid) {
    final entry = _cache[uid];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(uid);
      return null;
    }
    // Bump item order to make it Most Recently Used (move to the end)
    _cache.remove(uid);
    _cache[uid] = entry;
    return entry.user;
  }

  void clear() {
    _cache.clear();
  }
}

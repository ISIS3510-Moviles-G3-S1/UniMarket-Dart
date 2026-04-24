import 'dart:collection';

/// A generic LRU (Least Recently Used) cache backed by a [LinkedHashMap].
///
/// [LinkedHashMap] preserves insertion order. We exploit that to implement
/// O(1) LRU eviction: on every [get] the accessed entry is removed and
/// re-inserted at the tail (MRU position). When [put] exceeds [capacity],
/// the entry at the head (LRU position) is removed first.
///
/// Time complexity:
///   - [get]  → O(1) amortised (HashMap lookup + remove + insert)
///   - [put]  → O(1) amortised
///   - eviction → O(1) amortised
///
/// Usage in auth:
///   ```dart
///   static final _cache = LruCache<String, AppUser>(capacity: 50);
///   // capacity = 50: covers the current user + seller profiles browsed
///   // in a typical session without unbounded memory growth.
///   ```
class LruCache<K, V> {
  /// Creates a cache that holds at most [capacity] entries.
  ///
  /// [capacity] must be positive. A value of 50 is suitable for user-profile
  /// caching (1 current user + ~49 recently viewed seller profiles).
  LruCache({this.capacity = 50}) : assert(capacity > 0, 'capacity must be > 0');

  /// Maximum number of entries before the LRU entry is evicted.
  final int capacity;

  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  /// Current number of entries in the cache.
  int get length => _map.length;

  /// Returns the cached value for [key] and promotes it to the MRU position.
  ///
  /// Returns `null` if [key] is not present (cache miss).
  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    // Move to tail (MRU) via remove + re-insert.
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  /// Stores [value] under [key] at the MRU position.
  ///
  /// If [key] already exists it is updated in-place (still promoted to MRU).
  /// If the cache would exceed [capacity] the LRU entry (head) is evicted first.
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key); // re-insert as MRU below
    } else if (_map.length >= capacity) {
      _map.remove(_map.keys.first); // evict LRU (head of insertion-ordered map)
    }
    _map[key] = value;
  }

  /// Removes [key] from the cache. No-op if [key] is absent.
  void invalidate(K key) => _map.remove(key);

  /// Returns whether [key] is currently in the cache.
  bool containsKey(K key) => _map.containsKey(key);

  /// Removes all entries from the cache.
  void clear() => _map.clear();
}

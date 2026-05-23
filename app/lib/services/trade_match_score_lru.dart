import 'dart:collection';
import '../models/trade_match_score.dart';

class TradeMatchScoreLruCache {
  TradeMatchScoreLruCache._();
  static final TradeMatchScoreLruCache instance = TradeMatchScoreLruCache._();

  final LinkedHashMap<String, TradeMatchScore> _cache = LinkedHashMap<String, TradeMatchScore>();
  final int capacity = 64;

  String _getKey(String id1, String id2) {
    if (id1.compareTo(id2) <= 0) {
      return '$id1|$id2';
    } else {
      return '$id2|$id1';
    }
  }

  void put(String id1, String id2, TradeMatchScore score) {
    final key = _getKey(id1, id2);
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // Evict oldest
    }
    _cache[key] = score;
  }

  TradeMatchScore? get(String id1, String id2) {
    final key = _getKey(id1, id2);
    final score = _cache[key];
    if (score == null) return null;
    // Bump MRU
    _cache.remove(key);
    _cache[key] = score;
    return score;
  }

  void clear() {
    _cache.clear();
  }
}

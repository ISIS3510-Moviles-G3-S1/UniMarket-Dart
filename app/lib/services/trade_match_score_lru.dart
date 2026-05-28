import '../core/lru_cache.dart';
import '../models/trade_match_score.dart';

class TradeMatchScoreLruCache {
  TradeMatchScoreLruCache._();
  static final TradeMatchScoreLruCache instance = TradeMatchScoreLruCache._();

  final LruCache<String, TradeMatchScore> _cache = LruCache<String, TradeMatchScore>(capacity: 64);

  String _getKey(String id1, String id2) {
    if (id1.compareTo(id2) <= 0) {
      return '$id1|$id2';
    } else {
      return '$id2|$id1';
    }
  }

  void put(String id1, String id2, TradeMatchScore score) {
    final key = _getKey(id1, id2);
    _cache.put(key, score);
  }

  TradeMatchScore? get(String id1, String id2) {
    final key = _getKey(id1, id2);
    return _cache.get(key);
  }

  void clear() {
    _cache.clear();
  }
}

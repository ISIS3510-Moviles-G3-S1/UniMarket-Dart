import 'dart:collection';
import '../models/listing.dart';

class DonationListingsLRU {
  DonationListingsLRU._();
  static final DonationListingsLRU instance = DonationListingsLRU._();

  final LinkedHashMap<String, List<Listing>> _cache = LinkedHashMap<String, List<Listing>>();
  final int capacity = 16;

  void put(String category, List<Listing> listings) {
    if (_cache.containsKey(category)) {
      _cache.remove(category);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first); // evict oldest
    }
    _cache[category] = listings;
  }

  List<Listing>? get(String category) {
    final listings = _cache[category];
    if (listings == null) return null;
    // Bump
    _cache.remove(category);
    _cache[category] = listings;
    return listings;
  }

  void clear() {
    _cache.clear();
  }
}

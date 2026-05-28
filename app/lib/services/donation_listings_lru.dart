import '../core/lru_cache.dart';
import '../models/listing.dart';

class DonationListingsLRU {
  DonationListingsLRU._();
  static final DonationListingsLRU instance = DonationListingsLRU._();

  final LruCache<String, List<Listing>> _cache = LruCache<String, List<Listing>>(capacity: 16);

  void put(String category, List<Listing> listings) {
    _cache.put(category, listings);
  }

  List<Listing>? get(String category) {
    return _cache.get(category);
  }

  void clear() {
    _cache.clear();
  }
}

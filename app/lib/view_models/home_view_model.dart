import 'package:flutter/foundation.dart';
import '../models/listing.dart';
import '../data/mock_data.dart';
import '../core/user_activity_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<Listing> _featured = List.from(MockData.featuredListings);
  final Map<int, bool> _savedItems = {};
  final UserActivityService _activityService = UserActivityService();

  HomeViewModel() {
    for (final l in _featured) {
      _savedItems[l.id] = l.saved;
    }
  }

  List<Listing> get featured =>
      _featured
          .map((l) => l.copyWith(saved: _savedItems[l.id] ?? l.saved))
          .toList();

  bool isSaved(int id) => _savedItems[id] ?? false;

  void toggleSave(int id) {
    _savedItems[id] = !(_savedItems[id] ?? false);
    
    // Record user activity when liking an item
    if (_savedItems[id] == true) {
      _activityService.recordActivity('like');
    }
    
    notifyListeners();
  }
}

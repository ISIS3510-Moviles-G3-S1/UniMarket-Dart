import '../models/listing.dart';
import '../core/recommendation_system.dart';

/// Example usage for dynamic decorator combination.
/// This can be moved to a service or view model as needed.
class RecommendationService {
  final List<Listing> allItems;
  final List<String> userFrequentTags;
  final Map<String, DateTime> itemUploadDates;
  final DateTime newThreshold;

  RecommendationService({
    required this.allItems,
    required List<String> userFrequentCategories,
    required this.itemUploadDates,
    required this.newThreshold,
  }) : userFrequentTags = userFrequentCategories;

  /// Get personalized recommendations.
  List<Listing> getRecommendations() {
    ItemRecommendation base = AllItemsRecommendation(allItems);
    base = TagFilterDecorator(base, userFrequentTags);
    base = NewItemPriorityDecorator(base, newThreshold, itemUploadDates);
    return base.getItems();
  }

  /// Get count of new items per frequent tag.
  Map<String, int> getNewItemCounts() {
    ItemRecommendation base = AllItemsRecommendation(allItems);
    base = TagFilterDecorator(base, userFrequentTags);
    final newDecorator = NewItemPriorityDecorator(base, newThreshold, itemUploadDates);
    return newDecorator.countNewItemsPerTag();
  }
}

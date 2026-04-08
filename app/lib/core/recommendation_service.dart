import '../models/listing.dart';
import '../core/recommendation_system.dart';


class RecommendationService {
  final List<Listing> allItems;
  final List<String> userFrequentTags;
  final Map<String, DateTime> itemUploadDates;
  final DateTime newThreshold;
  final String? aiApiUrl;
  final String? userId;

  RecommendationService({
    required this.allItems,
    required List<String> userFrequentCategories,
    required this.itemUploadDates,
    required this.newThreshold,
    this.aiApiUrl,
    this.userId,
  }) : userFrequentTags = userFrequentCategories;

  /// Get personalized recommendations (sync fallback, AI async recommended for real app)
  List<Listing> getRecommendations() {
    ItemRecommendation base = AllItemsRecommendation(allItems);
    base = TagFilterDecorator(base, userFrequentTags);
    base = NewItemPriorityDecorator(base, newThreshold, itemUploadDates);
    // IA eliminada: no se aplica AIRecommendationDecorator
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

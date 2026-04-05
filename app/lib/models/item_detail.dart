import 'seller.dart';

/// Full item for detail page (gallery, seller, AI score, etc.).
class ItemDetail {
  final String id;
  final String name;
  final double price;
  final String condition;
  final Seller seller;
  final int aiScore;
  final String description;
  final List<String> images;
  final List<String> tags;
  final String? size;
  final String? category;
  final String? color;
  final String? style;
  final String? exchangeType;

  ItemDetail({
    required dynamic id,
    required this.name,
    required this.price,
    required this.condition,
    required this.seller,
    required this.aiScore,
    required this.description,
    required this.images,
    required this.tags,
    this.size,
    this.category,
    this.color,
    this.style,
    this.exchangeType,
  }) : id = id?.toString() ?? '';
}

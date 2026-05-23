class TradeMatchScore {
  final double priceFairness;
  final double tagOverlap;
  final double total;

  TradeMatchScore({
    required this.priceFairness,
    required this.tagOverlap,
    required this.total,
  });

  factory TradeMatchScore.fromJson(Map<String, dynamic> json) {
    return TradeMatchScore(
      priceFairness: (json['priceFairness'] ?? json['price_fairness'] ?? 0.0).toDouble(),
      tagOverlap: (json['tagOverlap'] ?? json['tag_overlap'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priceFairness': priceFairness,
      'tagOverlap': tagOverlap,
      'total': total,
    };
  }

  String get scoreBucket {
    if (total <= 25) return '0-25';
    if (total <= 50) return '25-50';
    if (total <= 75) return '50-75';
    return '75-100';
  }
}

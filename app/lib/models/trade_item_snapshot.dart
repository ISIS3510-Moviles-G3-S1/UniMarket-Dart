class TradeItemSnapshot {
  final String id;
  final String proposalID;
  final String listingID;
  final String title;
  final String? imageURL;
  final double price;
  final String ownerID;
  final String role; // "offered" | "desired"

  TradeItemSnapshot({
    required this.id,
    required this.proposalID,
    required this.listingID,
    required this.title,
    this.imageURL,
    required this.price,
    required this.ownerID,
    required this.role,
  });

  factory TradeItemSnapshot.fromJson(Map<String, dynamic> json) {
    return TradeItemSnapshot(
      id: json['id'] ?? '',
      proposalID: json['proposalID'] ?? json['proposal_id'] ?? '',
      listingID: json['listingID'] ?? json['listing_id'] ?? '',
      title: json['title'] ?? '',
      imageURL: json['imageURL'] ?? json['image_url'],
      price: (json['price'] ?? 0.0).toDouble(),
      ownerID: json['ownerID'] ?? json['owner_id'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proposalID': proposalID,
      'listingID': listingID,
      'title': title,
      'imageURL': imageURL,
      'price': price,
      'ownerID': ownerID,
      'role': role,
    };
  }
}

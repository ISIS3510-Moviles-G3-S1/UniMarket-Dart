import 'dart:convert';

class MeetupQrPayload {
  final String transactionId;
  final String listingId;
  final String sellerEmail;
  final String buyerEmail;

  const MeetupQrPayload({
    required this.transactionId,
    required this.listingId,
    required this.sellerEmail,
    required this.buyerEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'listingId': listingId,
      'sellerEmail': sellerEmail,
      'buyerEmail': buyerEmail,
    };
  }

  String encode() => jsonEncode(toJson());

  factory MeetupQrPayload.decode(String rawValue) {
    final dynamic decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR code payload is not a JSON object');
    }

    String readRequiredKey(String key) {
      final value = decoded[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing or invalid "$key" in QR payload');
      }
      return value.trim();
    }

    return MeetupQrPayload(
      transactionId: readRequiredKey('transactionId'),
      listingId: readRequiredKey('listingId'),
      sellerEmail: readRequiredKey('sellerEmail'),
      buyerEmail: readRequiredKey('buyerEmail'),
    );
  }
}

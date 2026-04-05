import 'package:uuid/uuid.dart';

enum MessageType { text, image }
enum MessageStatus { sending, sent, read, failed }

/// Represents a reply to another message
class ReplyTo {
  final String messageId;
  final String senderId;
  final String textPreview;

  ReplyTo({
    required this.messageId,
    required this.senderId,
    required this.textPreview,
  });

  ReplyTo copyWith({
    String? messageId,
    String? senderId,
    String? textPreview,
  }) {
    return ReplyTo(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      textPreview: textPreview ?? this.textPreview,
    );
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderId': senderId,
    'textPreview': textPreview,
  };

  factory ReplyTo.fromMap(Map<String, dynamic> map) => ReplyTo(
    messageId: map['messageId'] ?? '',
    senderId: map['senderId'] ?? '',
    textPreview: map['textPreview'] ?? '',
  );
}

/// Snapshot of listing at time of message
class ListingSnapshot {
  final String listingId;
  final String title;
  final double price;
  final String imagePath;

  ListingSnapshot({
    required this.listingId,
    required this.title,
    required this.price,
    required this.imagePath,
  });

  ListingSnapshot copyWith({
    String? listingId,
    String? title,
    double? price,
    String? imagePath,
  }) {
    return ListingSnapshot(
      listingId: listingId ?? this.listingId,
      title: title ?? this.title,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() => {
    'listingId': listingId,
    'title': title,
    'price': price,
    'imagePath': imagePath,
  };

  factory ListingSnapshot.fromMap(Map<String, dynamic> map) => ListingSnapshot(
    listingId: map['listingId'] ?? '',
    title: map['title'] ?? '',
    price: (map['price'] ?? 0).toDouble(),
    imagePath: map['imagePath'] ?? '',
  );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final List<String> imageURLs;
  final MessageType type;
  final DateTime sentAt;
  final DateTime? readAt;
  final MessageStatus status;
  final ReplyTo? replyTo;
  final ListingSnapshot? listingSnapshot;

  ChatMessage({
    String? id,
    required this.senderId,
    required this.text,
    List<String>? imageURLs,
    MessageType? type,
    DateTime? sentAt,
    this.readAt,
    MessageStatus? status,
    this.replyTo,
    this.listingSnapshot,
  })  : id = id ?? const Uuid().v4(),
        imageURLs = imageURLs ?? [],
        type = type ?? MessageType.text,
        sentAt = sentAt ?? DateTime.now(),
        status = status ?? MessageStatus.sending;

  bool get isFromCurrentUser => status != MessageStatus.failed;

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    List<String>? imageURLs,
    MessageType? type,
    DateTime? sentAt,
    DateTime? readAt,
    MessageStatus? status,
    ReplyTo? replyTo,
    ListingSnapshot? listingSnapshot,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageURLs: imageURLs ?? this.imageURLs,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      replyTo: replyTo ?? this.replyTo,
      listingSnapshot: listingSnapshot ?? this.listingSnapshot,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'imageURLs': imageURLs,
    'type': type.toString().split('.').last,
    'sentAt': sentAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
    'status': status.toString().split('.').last,
    'replyTo': replyTo?.toMap(),
    'listingSnapshot': listingSnapshot?.toMap(),
  };

  /// Create from Firestore document
  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      imageURLs: List<String>.from(map['imageURLs'] ?? []),
      type: _parseMessageType(map['type']),
      sentAt: DateTime.tryParse(map['sentAt'] ?? '') ?? DateTime.now(),
      readAt: DateTime.tryParse(map['readAt'] ?? ''),
      status: _parseMessageStatus(map['status']),
      replyTo: map['replyTo'] != null ? ReplyTo.fromMap(map['replyTo']) : null,
      listingSnapshot: map['listingSnapshot'] != null 
        ? ListingSnapshot.fromMap(map['listingSnapshot']) 
        : null,
    );
  }

  static MessageType _parseMessageType(String? type) {
    return type == 'image' ? MessageType.image : MessageType.text;
  }

  static MessageStatus _parseMessageStatus(String? status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }
}

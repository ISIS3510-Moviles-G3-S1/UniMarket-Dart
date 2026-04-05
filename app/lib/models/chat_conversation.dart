import 'package:uuid/uuid.dart';
import 'chat_message.dart';

class ChatConversation {
  final String id;
  final List<String> participants; // [buyerId, sellerId]
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatConversation({
    String? id,
    required this.participants,
    required this.buyerId,
    required this.sellerId,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        messages = messages ?? [];

  /// Get the last message preview
  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages';
    final last = messages.last;
    if (last.imageURLs.isNotEmpty) {
      return '📸 Image';
    }
    return last.text.isEmpty 
      ? 'Image message'
      : last.text.length > 50 
        ? '${last.text.substring(0, 50)}...'
        : last.text;
  }

  /// Add message to conversation
  void addMessage(ChatMessage message) {
    messages.add(message);
  }

  ChatConversation copyWith({
    String? id,
    List<String>? participants,
    String? buyerId,
    String? sellerId,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toMap() => {
    'participants': participants,
    'buyerId': buyerId,
    'sellerId': sellerId,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Create from Firestore document
  factory ChatConversation.fromMap(String id, Map<String, dynamic> map) {
    return ChatConversation(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      messages: [],
    );
  }
}

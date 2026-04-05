import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatStore extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<ChatConversation> _conversations = [];
  String? _currentUserId;

  List<ChatConversation> get conversations => _conversations;
  String? get currentUserId => _currentUserId;

  /// Initialize the store with current user
  Future<void> initialize() async {
    _currentUserId = _auth.currentUser?.uid;
    notifyListeners();
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    int count = 0;
    for (final conv in _conversations) {
      for (final msg in conv.messages) {
        if (msg.senderId != _currentUserId && msg.readAt == null) {
          count++;
        }
      }
    }
    return count;
  }

  /// Start a new conversation with a seller
  Future<String> startConversation({
    required String buyerId,
    required String sellerId,
    String? initialMessage,
  }) async {
    try {
      // Check if conversation already exists
      final existing = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: buyerId)
          .where('buyerId', isEqualTo: buyerId)
          .where('sellerId', isEqualTo: sellerId)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      // Create new conversation
      final conversationRef = await _firestore.collection('conversations').add({
        'participants': [buyerId, sellerId],
        'buyerId': buyerId,
        'sellerId': sellerId,
        'createdAt': Timestamp.now(),
      });

      // Add initial message
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        await conversationRef.collection('messages').add(
          ChatMessage(
            senderId: buyerId,
            text: initialMessage.trim(),
          ).toMap(),
        );
      }

      notifyListeners();
      return conversationRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    List<String>? imageURLs,
  }) async {
    try {
      if (_currentUserId == null) return;
      if (text.trim().isEmpty && (imageURLs?.isEmpty ?? true)) return;

      final message = ChatMessage(
        senderId: _currentUserId!,
        text: text.trim(),
        imageURLs: imageURLs ?? [],
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(message.toMap());

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      if (_currentUserId == null) return;

      final batch = _firestore.batch();
      final messagesRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      final unreadMessages = await messagesRef
          .where('senderId', isNotEqualTo: _currentUserId)
          .where('readAt', isNull: true)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readAt': Timestamp.now(),
        });
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Get conversation by ID
  ChatConversation? getConversation(String conversationId) {
    try {
      return _conversations.firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  /// Stream conversations for current user
  Stream<List<ChatConversation>> streamConversations() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatConversation> conversations = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final conversation = ChatConversation.fromMap(doc.id, data);

        // Load messages for this conversation
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .orderBy('sentAt', descending: false)
            .get();

        final messages = messagesSnapshot.docs
            .map((msgDoc) => ChatMessage.fromMap(msgDoc.id, msgDoc.data()))
            .toList();

        conversations.add(conversation.copyWith(messages: messages));
      }

      _conversations = conversations;
      notifyListeners();
      return conversations;
    });
  }

  /// Stream messages for a specific conversation
  Stream<List<ChatMessage>> streamConversationMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
            .toList());
  }
}

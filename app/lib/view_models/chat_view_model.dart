import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatViewModel extends ChangeNotifier {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ChatViewModel({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  Stream<List<Message>> get messagesStream {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  Future<void> sendMessage(String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final message = Message(
      id: '', // Firestore will generate
      senderId: currentUser.uid,
      text: text,
      imageURLs: [],
      type: 'text',
      sentAt: Timestamp.now(),
      status: 'sent',
    );

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());
  }

  Future<void> markMessagesAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messagesRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final unreadMessages = await messagesRef
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('readAt', isNull: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'readAt': Timestamp.now()});
    }
    await batch.commit();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatViewModel extends ChangeNotifier {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String itemName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ChatViewModel({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.itemName,
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

    try {
      // Ensure conversation document exists
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [currentUser.uid, otherUserId],
      }, SetOptions(merge: true));

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
    } catch (e) {
      // Ignore errors if permissions not set up yet
      print('Error sending message: $e');
    }
  }

  Future<void> sendInitialMessage() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if there are messages from current user
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (messages.docs.isNotEmpty) return; // already sent

      await sendMessage("Hi! Is the $itemName still available?");
    } catch (e) {
      // If permission denied or other error, still try to send the message
      await sendMessage("Hi! Is the $itemName still available?");
    }
  }

  Future<void> markMessagesAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
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
    } catch (e) {
      // Ignore errors if permissions not set up yet
    }
  }
  void dispose() {
    super.dispose();
  }
}
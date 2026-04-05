import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a message image to Firebase Storage
  /// Returns the download URL
  static Future<String> uploadMessageImage({
    required String conversationId,
    required String messageId,
    required File imageFile,
    required int index,
  }) async {
    try {
      final fileName = 'image_$index.jpg';
      final path = 'messages/$conversationId/$messageId/$fileName';

      final ref = _storage.ref(path);
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a listing image
  static Future<String> uploadListingImage({
    required String listingId,
    required File imageFile,
    required int index,
  }) async {
    try {
      final fileName = 'listing_$index.jpg';
      final path = 'listings/$listingId/$fileName';

      final ref = _storage.ref(path);
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an image from Firebase Storage
  static Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Upload profile image
  static Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final path = 'profiles/$userId/avatar.jpg';
      final ref = _storage.ref(path);
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      rethrow;
    }
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/listing.dart';

class ListingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _collection = 'listings';

  Stream<List<Listing>> getListings() {
    return _db.collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Listing.fromFirestore(doc)).toList());
  }

  Stream<List<Listing>> getListingsBySellerId(String sellerId) {
    return _db
        .collection(_collection)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Listing.fromFirestore(doc)).toList());
  }

  Future<Listing?> getListingById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return Listing.fromFirestore(doc);
  }

  Future<String> _uploadImage(dynamic image, String listingId, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final ref = _storage.ref().child('listings/${user.uid}/$listingId/image_$index.jpg');
    if (image is Uint8List) {
      await ref.putData(image, SettableMetadata(contentType: 'image/jpeg'));
    } else if (image is File) {
      await ref.putFile(image);
    } else {
      throw Exception('Unsupported image type');
    }
    return await ref.getDownloadURL();
  }

  Future<Listing> createListing({
    required Listing listing,
    required List<dynamic> images,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final docRef = _db.collection(_collection).doc();
    final listingId = docRef.id;
    List<String> imageUrls = [];
    for (int i = 0; i < images.length && i < 5; i++) {
      final url = await _uploadImage(images[i], listingId, i);
      imageUrls.add(url);
    }
    final data = listing.toFirestore()
      ..addAll({
        'sellerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'imageURLs': imageUrls,
        'imagePath': imageUrls.isNotEmpty ? imageUrls[0] : '',
      });
    await docRef.set(data);
    final doc = await docRef.get();
    return Listing.fromFirestore(doc);
  }

  Future<void> updateListing(Listing listing) async {
    await _db.collection(_collection).doc(listing.id).update(listing.toFirestore());
  }

  Future<void> deleteListing(Listing listing) async {
    for (final url in listing.imageURLs) {
      if (url.isNotEmpty) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }
    }
    await _db.collection(_collection).doc(listing.id).delete();
  }
}

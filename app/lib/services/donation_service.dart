import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_request.dart';
import '../models/listing.dart';

class DonationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'donationRequests';

  Future<void> createDonationRequest(DonationRequest request) async {
    await _db.collection(_collection).doc(request.id).set(request.toFirestore());
  }

  Future<void> updateDonationRequestStatus(String requestId, DonationRequestStatus status) async {
    final now = DateTime.now();
    await _db.collection(_collection).doc(requestId).update({
      'status': donationRequestStatusToString(status),
      'resolvedAt': Timestamp.fromDate(now),
    });
  }

  Stream<List<DonationRequest>> watchIncomingRequests(String sellerId) {
    return _db
        .collection(_collection)
        .where('sellerID', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DonationRequest.fromFirestore(doc)).toList());
  }

  Stream<List<DonationRequest>> watchOutgoingRequests(String requesterId) {
    return _db
        .collection(_collection)
        .where('requesterID', isEqualTo: requesterId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DonationRequest.fromFirestore(doc)).toList());
  }

  Future<List<Listing>> fetchDonationListings() async {
    final query = await _db
        .collection('listings')
        .where('kind', isEqualTo: 'donation')
        .where('status', isEqualTo: 'active')
        .get();
    return query.docs.map((doc) => Listing.fromFirestore(doc)).toList();
  }

  Future<List<DonationRequest>> fetchAllRequestsForListing(String listingId) async {
    final query = await _db
        .collection(_collection)
        .where('donationListingID', isEqualTo: listingId)
        .get();
    return query.docs.map((doc) => DonationRequest.fromFirestore(doc)).toList();
  }
}

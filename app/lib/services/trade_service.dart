import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trade_proposal.dart';

class TradeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'tradeProposals';

  Future<void> createTradeProposal(TradeProposal proposal) async {
    await _db.collection(_collection).doc(proposal.id).set(proposal.toFirestore());
  }

  Future<void> updateTradeProposalStatus(String proposalId, TradeProposalStatus status) async {
    final now = DateTime.now();
    await _db.collection(_collection).doc(proposalId).update({
      'status': tradeProposalStatusToString(status),
      'resolvedAt': Timestamp.fromDate(now),
    });
  }

  Stream<List<TradeProposal>> watchIncomingProposals(String toUserId) {
    return _db
        .collection(_collection)
        .where('toUserID', isEqualTo: toUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TradeProposal.fromFirestore(doc)).toList());
  }

  Stream<List<TradeProposal>> watchOutgoingProposals(String fromUserId) {
    return _db
        .collection(_collection)
        .where('fromUserID', isEqualTo: fromUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TradeProposal.fromFirestore(doc)).toList());
  }

  Future<List<TradeProposal>> fetchAllProposalsForListing(String listingId) async {
    final query = await _db
        .collection(_collection)
        .where('desiredListingID', isEqualTo: listingId)
        .get();
    return query.docs.map((doc) => TradeProposal.fromFirestore(doc)).toList();
  }
}

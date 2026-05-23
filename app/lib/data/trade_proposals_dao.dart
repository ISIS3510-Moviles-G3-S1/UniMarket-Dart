import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/trade_proposal.dart';
import '../models/trade_item_snapshot.dart';

class TradeProposalsDao {
  Future<void> insertOrUpdateProposal(TradeProposal proposal) async {
    final db = await AppDatabase().database;
    final data = {
      'id': proposal.id,
      'from_user_id': proposal.fromUserID,
      'to_user_id': proposal.toUserID,
      'desired_listing_id': proposal.desiredListingID,
      'offered_listing_id': proposal.offeredListingID,
      'message': proposal.message,
      'status': tradeProposalStatusToString(proposal.status),
      'price_delta': proposal.priceDelta,
      'created_at': proposal.createdAt.millisecondsSinceEpoch,
      'resolved_at': proposal.resolvedAt?.millisecondsSinceEpoch,
      'is_synced_proposal': proposal.isSyncedProposal,
      'is_synced_decision': proposal.isSyncedDecision,
      'retry_count': proposal.retryCount,
    };
    await db.insert(
      'trade_proposals',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertSnapshot(TradeItemSnapshot snapshot) async {
    final db = await AppDatabase().database;
    final data = {
      'id': snapshot.id,
      'proposal_id': snapshot.proposalID,
      'listing_id': snapshot.listingID,
      'title': snapshot.title,
      'image_url': snapshot.imageURL,
      'price': snapshot.price,
      'owner_id': snapshot.ownerID,
      'role': snapshot.role,
    };
    await db.insert(
      'trade_item_snapshots',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TradeProposal?> getProposal(String id) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_proposals',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<List<TradeProposal>> getIncomingProposals(String toUserId) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_proposals',
      where: 'to_user_id = ?',
      whereArgs: [toUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<TradeProposal>> getOutgoingProposals(String fromUserId) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_proposals',
      where: 'from_user_id = ?',
      whereArgs: [fromUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<TradeItemSnapshot>> getSnapshotsForProposal(String proposalId) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_item_snapshots',
      where: 'proposal_id = ?',
      whereArgs: [proposalId],
    );
    return maps.map((m) => TradeItemSnapshot.fromJson(m)).toList();
  }

  Future<List<TradeProposal>> getUnsyncedProposals() async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_proposals',
      where: 'is_synced_proposal = 0',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<TradeProposal>> getUnsyncedDecisions() async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trade_proposals',
      where: 'is_synced_decision = 0',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<void> deleteProposal(String id) async {
    final db = await AppDatabase().database;
    // Foreign key with cascade on delete should automatically handle snapshots deletion in sqlite if foreign_keys are enabled
    await db.delete(
      'trade_proposals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  TradeProposal _fromDbMap(Map<String, dynamic> map) {
    return TradeProposal(
      id: map['id'] as String,
      fromUserID: map['from_user_id'] as String,
      toUserID: map['to_user_id'] as String,
      desiredListingID: map['desired_listing_id'] as String,
      offeredListingID: map['offered_listing_id'] as String,
      message: map['message'] as String?,
      status: tradeProposalStatusFromString(map['status'] as String?),
      priceDelta: (map['price_delta'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      resolvedAt: map['resolved_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['resolved_at'] as int) : null,
      isSyncedProposal: map['is_synced_proposal'] as int,
      isSyncedDecision: map['is_synced_decision'] as int,
      retryCount: map['retry_count'] as int,
    );
  }
}

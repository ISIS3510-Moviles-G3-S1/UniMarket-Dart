import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../models/donation_request.dart';

class DonationRequestsDao {
  Future<void> insertOrUpdate(DonationRequest request) async {
    final db = await AppDatabase().database;
    final data = {
      'id': request.id,
      'donation_listing_id': request.donationListingID,
      'seller_id': request.sellerID,
      'requester_id': request.requesterID,
      'requester_message': request.requesterMessage,
      'status': donationRequestStatusToString(request.status),
      'created_at': request.createdAt.millisecondsSinceEpoch,
      'resolved_at': request.resolvedAt?.millisecondsSinceEpoch,
      'is_synced_claim': request.isSyncedClaim,
      'is_synced_decision': request.isSyncedDecision,
      'last_sync_attempt_at': request.lastSyncAttemptAt?.millisecondsSinceEpoch,
      'retry_count': request.retryCount,
    };
    await db.insert(
      'donation_requests',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DonationRequest?> getRequest(String id) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'donation_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<List<DonationRequest>> getIncomingRequests(String sellerId) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'donation_requests',
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<DonationRequest>> getOutgoingRequests(String requesterId) async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'donation_requests',
      where: 'requester_id = ?',
      whereArgs: [requesterId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<DonationRequest>> getUnsyncedClaims() async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'donation_requests',
      where: 'is_synced_claim = 0',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<List<DonationRequest>> getUnsyncedDecisions() async {
    final db = await AppDatabase().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'donation_requests',
      where: 'is_synced_decision = 0',
    );
    return maps.map((m) => _fromDbMap(m)).toList();
  }

  Future<void> deleteRequest(String id) async {
    final db = await AppDatabase().database;
    await db.delete(
      'donation_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  DonationRequest _fromDbMap(Map<String, dynamic> map) {
    return DonationRequest(
      id: map['id'] as String,
      donationListingID: map['donation_listing_id'] as String,
      sellerID: map['seller_id'] as String,
      requesterID: map['requester_id'] as String,
      requesterMessage: map['requester_message'] as String?,
      status: donationRequestStatusFromString(map['status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      resolvedAt: map['resolved_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['resolved_at'] as int) : null,
      isSyncedClaim: map['is_synced_claim'] as int,
      isSyncedDecision: map['is_synced_decision'] as int,
      lastSyncAttemptAt: map['last_sync_attempt_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_attempt_at'] as int) : null,
      retryCount: map['retry_count'] as int,
    );
  }
}

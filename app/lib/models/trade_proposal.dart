import 'package:cloud_firestore/cloud_firestore.dart';

enum TradeProposalStatus {
  pending,
  accepted,
  declined,
  withdrawn,
}

TradeProposalStatus tradeProposalStatusFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'accepted':
      return TradeProposalStatus.accepted;
    case 'declined':
      return TradeProposalStatus.declined;
    case 'withdrawn':
      return TradeProposalStatus.withdrawn;
    case 'pending':
    default:
      return TradeProposalStatus.pending;
  }
}

String tradeProposalStatusToString(TradeProposalStatus status) {
  switch (status) {
    case TradeProposalStatus.accepted:
      return 'accepted';
    case TradeProposalStatus.declined:
      return 'declined';
    case TradeProposalStatus.withdrawn:
      return 'withdrawn';
    case TradeProposalStatus.pending:
      return 'pending';
  }
}

class TradeProposal {
  final String id;
  final String fromUserID;
  final String toUserID;
  final String desiredListingID;
  final String offeredListingID;
  final String? message;
  final TradeProposalStatus status;
  final double priceDelta;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int isSyncedProposal;
  final int isSyncedDecision;
  final int retryCount;

  TradeProposal({
    required this.id,
    required this.fromUserID,
    required this.toUserID,
    required this.desiredListingID,
    required this.offeredListingID,
    this.message,
    this.status = TradeProposalStatus.pending,
    required this.priceDelta,
    required this.createdAt,
    this.resolvedAt,
    this.isSyncedProposal = 0,
    this.isSyncedDecision = 0,
    this.retryCount = 0,
  });

  TradeProposal copyWith({
    String? id,
    String? fromUserID,
    String? toUserID,
    String? desiredListingID,
    String? offeredListingID,
    String? message,
    TradeProposalStatus? status,
    double? priceDelta,
    DateTime? createdAt,
    DateTime? resolvedAt,
    int? isSyncedProposal,
    int? isSyncedDecision,
    int? retryCount,
  }) {
    return TradeProposal(
      id: id ?? this.id,
      fromUserID: fromUserID ?? this.fromUserID,
      toUserID: toUserID ?? this.toUserID,
      desiredListingID: desiredListingID ?? this.desiredListingID,
      offeredListingID: offeredListingID ?? this.offeredListingID,
      message: message ?? this.message,
      status: status ?? this.status,
      priceDelta: priceDelta ?? this.priceDelta,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isSyncedProposal: isSyncedProposal ?? this.isSyncedProposal,
      isSyncedDecision: isSyncedDecision ?? this.isSyncedDecision,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory TradeProposal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TradeProposal(
      id: doc.id,
      fromUserID: data['fromUserID'] ?? data['from_user_id'] ?? '',
      toUserID: data['toUserID'] ?? data['to_user_id'] ?? '',
      desiredListingID: data['desiredListingID'] ?? data['desired_listing_id'] ?? '',
      offeredListingID: data['offeredListingID'] ?? data['offered_listing_id'] ?? '',
      message: data['message'],
      status: tradeProposalStatusFromString(data['status']?.toString()),
      priceDelta: (data['priceDelta'] ?? data['price_delta'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is String)
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(),
      resolvedAt: (data['resolvedAt'] is Timestamp)
          ? (data['resolvedAt'] as Timestamp).toDate()
          : (data['resolvedAt'] is String)
              ? DateTime.parse(data['resolvedAt'])
              : null,
      isSyncedProposal: 1,
      isSyncedDecision: 1,
    );
  }

  factory TradeProposal.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return TradeProposal(
      id: json['id'] ?? '',
      fromUserID: json['fromUserID'] ?? json['from_user_id'] ?? '',
      toUserID: json['toUserID'] ?? json['to_user_id'] ?? '',
      desiredListingID: json['desiredListingID'] ?? json['desired_listing_id'] ?? '',
      offeredListingID: json['offeredListingID'] ?? json['offered_listing_id'] ?? '',
      message: json['message'],
      status: tradeProposalStatusFromString(json['status']?.toString()),
      priceDelta: (json['priceDelta'] ?? json['price_delta'] ?? 0.0).toDouble(),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      resolvedAt: parseDate(json['resolvedAt']),
      isSyncedProposal: json['isSyncedProposal'] ?? json['is_synced_proposal'] ?? 0,
      isSyncedDecision: json['isSyncedDecision'] ?? json['is_synced_decision'] ?? 0,
      retryCount: json['retryCount'] ?? json['retry_count'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserID': fromUserID,
      'toUserID': toUserID,
      'desiredListingID': desiredListingID,
      'offeredListingID': offeredListingID,
      'message': message,
      'status': tradeProposalStatusToString(status),
      'priceDelta': priceDelta,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserID': fromUserID,
      'toUserID': toUserID,
      'desiredListingID': desiredListingID,
      'offeredListingID': offeredListingID,
      'message': message,
      'status': tradeProposalStatusToString(status),
      'priceDelta': priceDelta,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'isSyncedProposal': isSyncedProposal,
      'isSyncedDecision': isSyncedDecision,
      'retryCount': retryCount,
    };
  }
}

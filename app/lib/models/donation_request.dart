import 'package:cloud_firestore/cloud_firestore.dart';

enum DonationRequestStatus {
  pending,
  approved,
  declined,
  withdrawn,
}

DonationRequestStatus donationRequestStatusFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'approved':
      return DonationRequestStatus.approved;
    case 'declined':
      return DonationRequestStatus.declined;
    case 'withdrawn':
      return DonationRequestStatus.withdrawn;
    case 'pending':
    default:
      return DonationRequestStatus.pending;
  }
}

String donationRequestStatusToString(DonationRequestStatus status) {
  switch (status) {
    case DonationRequestStatus.approved:
      return 'approved';
    case DonationRequestStatus.declined:
      return 'declined';
    case DonationRequestStatus.withdrawn:
      return 'withdrawn';
    case DonationRequestStatus.pending:
      return 'pending';
  }
}

class DonationRequest {
  final String id;
  final String donationListingID;
  final String sellerID;
  final String requesterID;
  final String? requesterMessage;
  final DonationRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int isSyncedClaim; // 0 = false, 1 = true
  final int isSyncedDecision; // 0 = false, 1 = true
  final DateTime? lastSyncAttemptAt;
  final int retryCount;

  DonationRequest({
    required this.id,
    required this.donationListingID,
    required this.sellerID,
    required this.requesterID,
    this.requesterMessage,
    this.status = DonationRequestStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.isSyncedClaim = 0,
    this.isSyncedDecision = 0,
    this.lastSyncAttemptAt,
    this.retryCount = 0,
  });

  DonationRequest copyWith({
    String? id,
    String? donationListingID,
    String? sellerID,
    String? requesterID,
    String? requesterMessage,
    DonationRequestStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    int? isSyncedClaim,
    int? isSyncedDecision,
    DateTime? lastSyncAttemptAt,
    int? retryCount,
  }) {
    return DonationRequest(
      id: id ?? this.id,
      donationListingID: donationListingID ?? this.donationListingID,
      sellerID: sellerID ?? this.sellerID,
      requesterID: requesterID ?? this.requesterID,
      requesterMessage: requesterMessage ?? this.requesterMessage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isSyncedClaim: isSyncedClaim ?? this.isSyncedClaim,
      isSyncedDecision: isSyncedDecision ?? this.isSyncedDecision,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory DonationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DonationRequest(
      id: doc.id,
      donationListingID: data['donationListingID'] ?? data['donation_listing_id'] ?? '',
      sellerID: data['sellerID'] ?? data['seller_id'] ?? '',
      requesterID: data['requesterID'] ?? data['requester_id'] ?? '',
      requesterMessage: data['requesterMessage'] ?? data['requester_message'],
      status: donationRequestStatusFromString(data['status']?.toString()),
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
      isSyncedClaim: 1, // Reading from Firestore means it's synced
      isSyncedDecision: 1,
    );
  }

  factory DonationRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return DonationRequest(
      id: json['id'] ?? '',
      donationListingID: json['donationListingID'] ?? json['donation_listing_id'] ?? '',
      sellerID: json['sellerID'] ?? json['seller_id'] ?? '',
      requesterID: json['requesterID'] ?? json['requester_id'] ?? '',
      requesterMessage: json['requesterMessage'] ?? json['requester_message'],
      status: donationRequestStatusFromString(json['status']?.toString()),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      resolvedAt: parseDate(json['resolvedAt']),
      isSyncedClaim: json['isSyncedClaim'] ?? json['is_synced_claim'] ?? 0,
      isSyncedDecision: json['isSyncedDecision'] ?? json['is_synced_decision'] ?? 0,
      lastSyncAttemptAt: parseDate(json['lastSyncAttemptAt']),
      retryCount: json['retryCount'] ?? json['retry_count'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'donationListingID': donationListingID,
      'sellerID': sellerID,
      'requesterID': requesterID,
      'requesterMessage': requesterMessage,
      'status': donationRequestStatusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donationListingID': donationListingID,
      'sellerID': sellerID,
      'requesterID': requesterID,
      'requesterMessage': requesterMessage,
      'status': donationRequestStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'isSyncedClaim': isSyncedClaim,
      'isSyncedDecision': isSyncedDecision,
      'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }
}

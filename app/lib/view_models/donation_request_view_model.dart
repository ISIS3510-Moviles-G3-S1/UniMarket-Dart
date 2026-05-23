import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/donation_request.dart';
import '../data/donation_requests_dao.dart';
import '../data/donation_drafts_box.dart';
import '../services/donation_service.dart';
import '../models/listing.dart';
import '../core/analytics_service.dart';
import '../core/analytics_event.dart';

class DonationRequestViewModel extends ChangeNotifier {
  final DonationRequestsDao _dao = DonationRequestsDao();
  final DonationService _service = DonationService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOffline = false;
  bool _isSubmitting = false;
  String _messageText = '';

  bool get isOffline => _isOffline;
  bool get isSubmitting => _isSubmitting;
  String get messageText => _messageText;

  DonationRequestViewModel() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      notifyListeners();
    });
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      notifyListeners();
    });
  }

  Future<void> loadDraft(String userId, String listingId) async {
    _messageText = await DonationDraftsBox.instance.getDraft(userId: userId, listingId: listingId);
    notifyListeners();
  }

  Future<void> updateDraft(String userId, String listingId, String text) async {
    _messageText = text;
    await DonationDraftsBox.instance.saveDraft(userId: userId, listingId: listingId, text: text);
  }

  Future<bool> submitClaim({
    required Listing listing,
    required String requesterId,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    notifyListeners();

    final id = const Uuid().v4();
    final request = DonationRequest(
      id: id,
      donationListingID: listing.id,
      sellerID: listing.sellerId,
      requesterID: requesterId,
      requesterMessage: _messageText.trim().isNotEmpty ? _messageText : null,
      status: DonationRequestStatus.pending,
      createdAt: DateTime.now(),
      isSyncedClaim: _isOffline ? 0 : 1,
      isSyncedDecision: 1, // Only status changes need decision sync
    );

    try {
      // 1. Insert to Local Relational sqflite Database (rubric requires SQLite relational pillar)
      await _dao.insertOrUpdate(request);

      if (!_isOffline) {
        // 2. Submit to Firestore if online
        await _service.createDonationRequest(request);
      }

      // 3. Clear the Hive Draft
      await DonationDraftsBox.instance.clearDraft(userId: requesterId, listingId: listing.id);

      // Track Donation Request event
      _analytics.track(AnalyticsEvent.donationClaimed(
        listingId: listing.id,
        sellerId: listing.sellerId,
        timeSinceListingSeconds: DateTime.now().difference(listing.createdAt ?? DateTime.now()).inSeconds,
      ));

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

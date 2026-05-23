import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/trade_proposal.dart';
import '../models/trade_item_snapshot.dart';
import '../models/trade_match_score.dart';
import '../models/listing.dart';
import '../data/trade_proposals_dao.dart';
import '../data/trade_drafts_box.dart';
import '../services/trade_service.dart';
import '../services/trade_match_score_lru.dart';
import '../services/trade_match_score_isolate.dart';
import '../core/analytics_service.dart';
import '../core/analytics_event.dart';

class ProposeTradeViewModel extends ChangeNotifier {
  final TradeProposalsDao _dao = TradeProposalsDao();
  final TradeService _service = TradeService();
  final AnalyticsService _analytics = AnalyticsService.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final Listing desiredListing;
  final String currentUserId;

  bool _isOffline = false;
  bool _isLoadingCandidates = false;
  bool _isSubmitting = false;
  List<Listing> _myActiveListings = [];
  Listing? _selectedOfferedListing;
  String _message = '';

  bool get isOffline => _isOffline;
  bool get isLoadingCandidates => _isLoadingCandidates;
  bool get isSubmitting => _isSubmitting;
  List<Listing> get myActiveListings => _myActiveListings;
  Listing? get selectedOfferedListing => _selectedOfferedListing;
  String get message => _message;

  ProposeTradeViewModel({
    required this.desiredListing,
    required this.currentUserId,
  }) {
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

  Future<void> loadDraft() async {
    _isLoadingCandidates = true;
    notifyListeners();

    try {
      final draft = await TradeDraftsBox.instance.getDraft(
        userId: currentUserId,
        desiredListingId: desiredListing.id,
      );

      if (draft != null) {
        _message = draft['message'] ?? '';
        final offeredId = draft['offeredListingId'] as String?;
        if (offeredId != null) {
          // Temporarily set if loaded from list later
          _selectedOfferedListing = _myActiveListings.firstWhere(
            (l) => l.id == offeredId,
            orElse: () => Listing(
              id: offeredId,
              sellerId: currentUserId,
              title: 'Draft Item',
              price: 0,
              conditionTag: '',
              description: '',
              sellerName: '',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading trade draft: $e');
    } finally {
      _isLoadingCandidates = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(String msg, String? offeredId) async {
    _message = msg;
    if (offeredId != null) {
      await TradeDraftsBox.instance.saveDraft(
        userId: currentUserId,
        desiredListingId: desiredListing.id,
        offeredListingId: offeredId,
        message: msg,
      );
    }
  }

  Future<void> fetchMyCandidates(List<Listing> allMyListings) async {
    // Candidates must be active, not the desired model itself, and belong to the current logined user
    _myActiveListings = allMyListings.where((l) => l.sellerId == currentUserId && l.isActive && l.id != desiredListing.id).toList();

    // Trigger compute isolate to recompute scores for all candidates in bulk
    if (_myActiveListings.isNotEmpty) {
      final offeredPayloads = _myActiveListings.map((l) => {
        'id': l.id,
        'price': l.price.toDouble(),
        'tags': l.tags,
      }).toList();

      final scores = await TradeMatchScoreIsolate.calculateScoresBulk(
        desiredId: desiredListing.id,
        desiredPrice: desiredListing.price.toDouble(),
        desiredTags: desiredListing.tags,
        offeredListings: offeredPayloads,
      );

      // Write computed matches back to the LRU Cache
      scores.forEach((offeredId, score) {
        TradeMatchScoreLruCache.instance.put(offeredId, desiredListing.id, score);
      });
    }

    // Resolve draft matched item if we loaded a generic shell
    if (_selectedOfferedListing != null) {
      final realItem = _myActiveListings.firstWhere((l) => l.id == _selectedOfferedListing!.id, orElse: () => _selectedOfferedListing!);
      _selectedOfferedListing = realItem;
    }

    notifyListeners();
  }

  void selectOfferedListing(Listing? listing) {
    _selectedOfferedListing = listing;
    if (listing != null) {
      saveDraft(_message, listing.id);
    }
    notifyListeners();
  }

  TradeMatchScore? getScoreFor(Listing offered) {
    // Per-row score fetch (gets computed from LRU or returns computed placeholder)
    final cached = TradeMatchScoreLruCache.instance.get(offered.id, desiredListing.id);
    return cached;
  }

  Future<bool> submitProposal() async {
    if (_isSubmitting || _selectedOfferedListing == null) return false;
    _isSubmitting = true;
    notifyListeners();

    final id = const Uuid().v4();
    final priceDelta = (_selectedOfferedListing!.price - desiredListing.price).toDouble();

    final proposal = TradeProposal(
      id: id,
      fromUserID: currentUserId,
      toUserID: desiredListing.sellerId,
      desiredListingID: desiredListing.id,
      offeredListingID: _selectedOfferedListing!.id,
      message: _message.trim().isNotEmpty ? _message : null,
      status: TradeProposalStatus.pending,
      priceDelta: priceDelta,
      createdAt: DateTime.now(),
      isSyncedProposal: _isOffline ? 0 : 1,
      isSyncedDecision: 1, // Decisions are synced separately!
    );

    // Create item snapshots protecting history
    final desiredSnapshot = TradeItemSnapshot(
      id: const Uuid().v4(),
      proposalID: id,
      listingID: desiredListing.id,
      title: desiredListing.title,
      imageURL: desiredListing.primaryImageUrl,
      price: desiredListing.price.toDouble(),
      ownerID: desiredListing.sellerId,
      role: 'desired',
    );

    final offeredSnapshot = TradeItemSnapshot(
      id: const Uuid().v4(),
      proposalID: id,
      listingID: _selectedOfferedListing!.id,
      title: _selectedOfferedListing!.title,
      imageURL: _selectedOfferedListing!.primaryImageUrl,
      price: _selectedOfferedListing!.price.toDouble(),
      ownerID: currentUserId,
      role: 'offered',
    );

    try {
      // 1. Write structured transaction to SQL relational storage
      await _dao.insertOrUpdateProposal(proposal);
      await _dao.insertSnapshot(desiredSnapshot);
      await _dao.insertSnapshot(offeredSnapshot);

      if (!_isOffline) {
        // 2. Publish to Firestore
        await _service.createTradeProposal(proposal);
      }

      // 3. Purge Hive drafts box on completion
      await TradeDraftsBox.instance.clearDraft(
        userId: currentUserId,
        desiredListingId: desiredListing.id,
      );

      // Track analytics
      _analytics.track(AnalyticsEvent.tradeProposed(
        desiredListingId: desiredListing.id,
        offeredListingId: _selectedOfferedListing!.id,
        priceDelta: priceDelta,
      ));

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error submit proposal: $e');
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

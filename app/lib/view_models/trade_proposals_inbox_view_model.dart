import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/trade_proposal.dart';
import '../models/app_user.dart';
import '../data/trade_proposals_dao.dart';
import '../data/trade_inbox_snapshot.dart';
import '../services/trade_service.dart';
import '../services/trade_counterparty_profile_cache.dart';

class TradeProposalsInboxViewModel extends ChangeNotifier {
  final TradeProposalsDao _dao = TradeProposalsDao();
  final TradeService _service = TradeService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<TradeProposal>>? _firebaseSubscription;

  final String userId;
  List<TradeProposal> _proposals = [];
  bool _isLoading = false;
  bool _isOffline = false;
  DateTime? _lastRefreshed;

  List<TradeProposal> get proposals => _proposals;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  DateTime? get lastRefreshed => _lastRefreshed;

  TradeProposalsInboxViewModel({required this.userId}) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupInboxStream();
    });
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupInboxStream();
    });
  }

  void _setupInboxStream() {
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;

    if (_isOffline) {
      _loadOfflineSnapshot();
    } else {
      _isLoading = true;
      notifyListeners();
      _firebaseSubscription = _service.watchIncomingProposals(userId).listen((firestoreProposals) async {
        // Sync back to local SQLite DB as cache
        for (final p in firestoreProposals) {
          final local = await _dao.getProposal(p.id);
          if (local == null || local.status != p.status) {
            await _dao.insertOrUpdateProposal(p.copyWith(
              isSyncedProposal: 1,
              isSyncedDecision: 1,
            ));
          }
        }
        _proposals = firestoreProposals;
        _lastRefreshed = DateTime.now();
        _isLoading = false;
        notifyListeners();

        // Save snapshot for offline inbox browsing
        final jsonList = firestoreProposals.map((p) => p.toJson()).toList();
        await TradeInboxSnapshot.persist(jsonList);
      }, onError: (e) {
        _isLoading = false;
        _loadOfflineSnapshot();
      });
    }
  }

  Future<void> _loadOfflineSnapshot() async {
    _isLoading = true;
    notifyListeners();

    final snapshot = await TradeInboxSnapshot.load();
    if (snapshot != null) {
      final list = snapshot['list'] as List? ?? [];
      _proposals = list.map((item) => TradeProposal.fromJson(Map<String, dynamic>.from(item))).toList();
      final ts = snapshot['timestamp'] as int?;
      if (ts != null) {
        _lastRefreshed = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } else {
      // Fallback to SQLite reads
      _proposals = await _dao.getIncomingProposals(userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<AppUser?> getCounterpartyProfile(String uid) async {
    // 1. Check custom LRU cache
    final cached = TradeCounterpartyProfileCache.instance.get(uid);
    if (cached != null) return cached;

    // 2. Fetch from Firestore if online
    if (!_isOffline) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final user = AppUser.fromFirestore(doc);
          TradeCounterpartyProfileCache.instance.put(uid, user);
          return user;
        }
      } catch (e) {
        debugPrint('Error fetching counterparty profile: $e');
      }
    }
    return null;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseSubscription?.cancel();
    super.dispose();
  }
}

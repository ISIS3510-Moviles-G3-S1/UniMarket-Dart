import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/trade_proposal.dart';
import '../data/trade_proposals_dao.dart';
import '../services/trade_service.dart';

class MyTradeProposalsViewModel extends ChangeNotifier {
  final TradeProposalsDao _dao = TradeProposalsDao();
  final TradeService _service = TradeService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<TradeProposal>>? _firebaseSubscription;

  final String userId;
  List<TradeProposal> _proposals = [];
  bool _isLoading = false;
  bool _isOffline = false;

  List<TradeProposal> get proposals => _proposals;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  MyTradeProposalsViewModel({required this.userId}) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupProposalsStream();
    });
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupProposalsStream();
    });
  }

  void _setupProposalsStream() {
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;

    if (_isOffline) {
      _loadLocalProposals();
    } else {
      _isLoading = true;
      notifyListeners();
      _firebaseSubscription = _service.watchOutgoingProposals(userId).listen((firestoreProposals) async {
        // Cache firestore updates back to SQLite
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
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _isLoading = false;
        _loadLocalProposals();
      });
    }
  }

  Future<void> _loadLocalProposals() async {
    _isLoading = true;
    notifyListeners();
    _proposals = await _dao.getOutgoingProposals(userId);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseSubscription?.cancel();
    super.dispose();
  }
}

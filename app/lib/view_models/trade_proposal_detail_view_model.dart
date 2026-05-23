import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/trade_proposal.dart';
import '../models/trade_item_snapshot.dart';
import '../data/trade_proposals_dao.dart';
import '../services/trade_service.dart';

class TradeProposalDetailViewModel extends ChangeNotifier {
  final TradeProposalsDao _dao = TradeProposalsDao();
  final TradeService _service = TradeService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  TradeProposal proposal;
  List<TradeItemSnapshot> _snapshots = [];
  bool _isLoading = false;
  bool _isOffline = false;

  List<TradeItemSnapshot> get snapshots => _snapshots;
  TradeItemSnapshot? get desiredSnapshot => _snapshots.isEmpty ? null : _snapshots.firstWhere((s) => s.role == 'desired', orElse: () => _snapshots.first);
  TradeItemSnapshot? get offeredSnapshot => _snapshots.isEmpty ? null : _snapshots.firstWhere((s) => s.role == 'offered', orElse: () => _snapshots.first);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  TradeProposalDetailViewModel({required this.proposal}) {
    _initConnectivity();
    loadSnapshots();
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

  Future<void> loadSnapshots() async {
    _isLoading = true;
    notifyListeners();

    try {
      _snapshots = await _dao.getSnapshotsForProposal(proposal.id);
    } catch (e) {
      debugPrint('Error loading trade item snapshots: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resolveProposal(TradeProposalStatus targetStatus) async {
    final updated = proposal.copyWith(
      status: targetStatus,
      resolvedAt: DateTime.now(),
      isSyncedDecision: _isOffline ? 0 : 1,
    );

    // Update locally instantly for optimistic UI response offline
    proposal = updated;
    notifyListeners();

    try {
      // 1. Relational database update inside SQLite
      await _dao.insertOrUpdateProposal(updated);

      if (!_isOffline) {
        // 2. Sync to firestore
        await _service.updateTradeProposalStatus(proposal.id, targetStatus);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating trade proposal status: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

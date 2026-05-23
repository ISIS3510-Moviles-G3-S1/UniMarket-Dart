import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'trade_proposals_dao.dart';
import '../services/trade_service.dart';

class TradeSyncQueue {
  final TradeProposalsDao _dao;
  final TradeService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDraining = false;

  TradeSyncQueue(this._dao, this._service);

  void bind() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        drain();
      }
    });
  }

  void unbind() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> drain() async {
    if (_isDraining) return;
    _isDraining = true;

    try {
      // 1. Drain proposals (isSyncedProposal == 0)
      final unsyncedProposals = await _dao.getUnsyncedProposals();
      for (final proposal in unsyncedProposals) {
        try {
          await _service.createTradeProposal(proposal);
          final updated = proposal.copyWith(
            isSyncedProposal: 1,
          );
          await _dao.insertOrUpdateProposal(updated);
        } catch (e) {
          final updated = proposal.copyWith(
            retryCount: proposal.retryCount + 1,
          );
          await _dao.insertOrUpdateProposal(updated);
        }
      }

      // 2. Drain decisions (isSyncedDecision == 0)
      final unsyncedDecisions = await _dao.getUnsyncedDecisions();
      for (final proposal in unsyncedDecisions) {
        if (proposal.isSyncedProposal == 0) continue;
        try {
          await _service.updateTradeProposalStatus(proposal.id, proposal.status);
          final updated = proposal.copyWith(
            isSyncedDecision: 1,
          );
          await _dao.insertOrUpdateProposal(updated);
        } catch (e) {
          final updated = proposal.copyWith(
            retryCount: proposal.retryCount + 1,
          );
          await _dao.insertOrUpdateProposal(updated);
        }
      }
    } finally {
      _isDraining = false;
    }
  }
}

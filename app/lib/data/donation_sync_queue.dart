import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'donation_requests_dao.dart';
import '../services/donation_service.dart';

class DonationSyncQueue {
  final DonationRequestsDao _dao;
  final DonationService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDraining = false;

  DonationSyncQueue(this._dao, this._service);

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
      // 1. Drain claims (isSyncedClaim == 0)
      final unsyncedClaims = await _dao.getUnsyncedClaims();
      for (final request in unsyncedClaims) {
        try {
          await _service.createDonationRequest(request);
          final updated = request.copyWith(
            isSyncedClaim: 1,
            lastSyncAttemptAt: DateTime.now(),
          );
          await _dao.insertOrUpdate(updated);
        } catch (e) {
          final updated = request.copyWith(
            retryCount: request.retryCount + 1,
            lastSyncAttemptAt: DateTime.now(),
          );
          await _dao.insertOrUpdate(updated);
        }
      }

      // 2. Drain decisions (isSyncedDecision == 0)
      final unsyncedDecisions = await _dao.getUnsyncedDecisions();
      for (final request in unsyncedDecisions) {
        // Only attempt to sync decision if the claim itself is already synced!
        if (request.isSyncedClaim == 0) continue;
        try {
          await _service.updateDonationRequestStatus(request.id, request.status);
          final updated = request.copyWith(
            isSyncedDecision: 1,
            lastSyncAttemptAt: DateTime.now(),
          );
          await _dao.insertOrUpdate(updated);
        } catch (e) {
          final updated = request.copyWith(
            retryCount: request.retryCount + 1,
            lastSyncAttemptAt: DateTime.now(),
          );
          await _dao.insertOrUpdate(updated);
        }
      }
    } finally {
      _isDraining = false;
    }
  }
}

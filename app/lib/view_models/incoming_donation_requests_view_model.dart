import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_request.dart';
import '../models/app_user.dart';
import '../data/donation_requests_dao.dart';
import '../services/donation_service.dart';
import '../services/donation_requester_profile_cache.dart';

class IncomingDonationRequestsViewModel extends ChangeNotifier {
  final DonationRequestsDao _dao = DonationRequestsDao();
  final DonationService _service = DonationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<DonationRequest>>? _firebaseSubscription;

  List<DonationRequest> _requests = [];
  bool _isLoading = false;
  bool _isOffline = false;
  final String sellerId;

  List<DonationRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  IncomingDonationRequestsViewModel({required this.sellerId}) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupRequestsStream();
    });
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _setupRequestsStream();
    });
  }

  void _setupRequestsStream() {
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;

    if (_isOffline) {
      _loadLocalRequests();
    } else {
      _isLoading = true;
      notifyListeners();
      _firebaseSubscription = _service.watchIncomingRequests(sellerId).listen((firestoreRequests) async {
        // Sync firestore requests back to SQLite local db as cache
        for (final request in firestoreRequests) {
          final local = await _dao.getRequest(request.id);
          if (local == null || local.status != request.status) {
            await _dao.insertOrUpdate(request.copyWith(
              isSyncedClaim: 1,
              isSyncedDecision: 1,
            ));
          }
        }
        _requests = firestoreRequests;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _isLoading = false;
        _loadLocalRequests();
      });
    }
  }

  Future<void> _loadLocalRequests() async {
    _isLoading = true;
    notifyListeners();
    _requests = await _dao.getIncomingRequests(sellerId);
    _isLoading = false;
    notifyListeners();
  }

  Future<AppUser?> getRequesterProfile(String uid) async {
    // 1. Check custom LRU cache
    final cached = DonationRequesterProfileCache.instance.get(uid);
    if (cached != null) return cached;

    // 2. Fetch from Firestore if online
    if (!_isOffline) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final user = AppUser.fromFirestore(doc);
          DonationRequesterProfileCache.instance.put(uid, user);
          return user;
        }
      } catch (e) {
        debugPrint('Error fetching claimant profile: $e');
      }
    }
    return null;
  }

  Future<bool> resolveRequest(String requestId, DonationRequestStatus targetStatus) async {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final request = _requests[idx];
    final updated = request.copyWith(
      status: targetStatus,
      resolvedAt: DateTime.now(),
      isSyncedDecision: _isOffline ? 0 : 1,
    );

    // Update UI instantly
    _requests[idx] = updated;
    notifyListeners();

    try {
      // 1. Relational database update inside SQLite
      await _dao.insertOrUpdate(updated);

      if (!_isOffline) {
        // 2. Sync to firestore
        await _service.updateDonationRequestStatus(requestId, targetStatus);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating request status: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseSubscription?.cancel();
    super.dispose();
  }
}

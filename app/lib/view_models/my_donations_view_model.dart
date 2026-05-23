import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/donation_request.dart';
import '../data/donation_requests_dao.dart';
import '../services/donation_service.dart';

class MyDonationsViewModel extends ChangeNotifier {
  final DonationRequestsDao _dao = DonationRequestsDao();
  final DonationService _service = DonationService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<DonationRequest>>? _firebaseSubscription;

  List<DonationRequest> _requests = [];
  bool _isLoading = false;
  bool _isOffline = false;
  final String requesterId;

  List<DonationRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  MyDonationsViewModel({required this.requesterId}) {
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
      _firebaseSubscription = _service.watchOutgoingRequests(requesterId).listen((firestoreRequests) async {
        // Cache firestore updates back to SQLite
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
    _requests = await _dao.getOutgoingRequests(requesterId);
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

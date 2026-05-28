import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/listing.dart';
import '../services/donation_service.dart';
import '../services/donation_listings_lru.dart';
import '../services/donation_parser_isolate.dart';
import '../data/donation_offline_snapshot.dart';
import '../models/listing_kind.dart';

class DonationsBrowseViewModel extends ChangeNotifier {
  final DonationService _service = DonationService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<Listing>>? _isolateStreamSubscription;

  List<Listing> _listings = [];
  bool _isLoading = false;
  bool _isOffline = false;
  DateTime? _lastRefreshed;
  String? _errorMessage;
  String _selectedCategory = 'all';

  List<Listing> get listings => _listings;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  DateTime? get lastRefreshed => _lastRefreshed;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  DonationsBrowseViewModel() {
    _loadPreferences().then((_) {
      _initConnectivity();
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCategory = prefs.getString('last_selected_donation_category') ?? 'all';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_donation_category', category);
    } catch (_) {}
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = _isOffline;
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (wasOffline && !_isOffline) {
        fetchDonations(forceRefresh: true);
      }
      notifyListeners();
    });
    // Initial check
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      fetchDonations();
    });
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _savePreferences(category);
    _applyFilterAndCache();
  }

  Future<void> fetchDonations({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Cancel any previous isolate stream subscription
    await _isolateStreamSubscription?.cancel();

    try {
      if (_isOffline) {
        // Load raw content from local snapshot
        final content = await DonationOfflineSnapshot.loadRaw();
        if (content != null) {
          // Parse using background native Isolate stream
          final completer = Completer<void>();
          final stream = DonationParserIsolate().parseDonationsStream(content);
          
          _isolateStreamSubscription = stream.listen((rawListings) {
            _listings = rawListings.where((l) => l.kind == ListingKind.donation && l.isActive).toList();
            _lastRefreshed = DateTime.now(); // Loaded from offline storage
            completer.complete();
          }, onError: (err) {
            _errorMessage = err.toString();
            completer.complete();
          }, onDone: () {
            if (!completer.isCompleted) completer.complete();
          });

          await completer.future;
        } else {
          _listings = [];
        }
      } else {
        // Try to get from LRU cache first if not forceRefreshed
        final cached = DonationListingsLRU.instance.get(_selectedCategory);
        if (cached != null && !forceRefresh) {
          _listings = cached;
          _lastRefreshed ??= DateTime.now();
        } else {
          final onlineListings = await _service.fetchDonationListings();
          _listings = onlineListings;
          _lastRefreshed = DateTime.now();

          // Persist the full uncategorized list into snapshot for offline use
          final jsonList = onlineListings.map((l) => l.toJson()).toList();
          await DonationOfflineSnapshot.persist(jsonList);

          // Update Category cache for all
          DonationListingsLRU.instance.put('all', onlineListings);
          _applyFilterAndCache();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilterAndCache() {
    if (_listings.isEmpty) return;

    List<Listing> filtered;
    if (_selectedCategory == 'all') {
      filtered = _listings;
    } else {
      filtered = _listings.where((l) => l.tags.any((t) => t.toLowerCase() == _selectedCategory.toLowerCase()) || l.conditionTag.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }

    if (!_isOffline) {
      DonationListingsLRU.instance.put(_selectedCategory, filtered);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

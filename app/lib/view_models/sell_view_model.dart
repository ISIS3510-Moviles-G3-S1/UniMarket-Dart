import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import '../data/listing_service.dart';
import '../models/listing.dart';
import 'session_view_model.dart';

class SellViewModel extends ChangeNotifier {
  SellViewModel(this._session);

  final ListingService _listingService = ListingService();
  SessionViewModel _session;
    void updateSession(SessionViewModel session) {
      _session = session;
    }
  bool _aiLoading = false;
  bool _aiDone = false;
  double _aiProgress = 0;
  bool _published = false;

  String _title = '';
  String _description = '';
  String _price = '';
  String _condition = 'Good';
  String _exchangeType = 'sell';
  List<String> _tags = [];
  String _tagsInput = '';
  List<dynamic> _images = [];

  bool get aiLoading => _aiLoading;
  bool get aiDone => _aiDone;
  double get aiProgress => _aiProgress;
  bool get published => _published;

  String get title => _title;
  set title(String v) {
    _title = v;
    notifyListeners();
  }

  String get description => _description;
  set description(String v) {
    _description = v;
    notifyListeners();
  }

  String get price => _price;
  set price(String v) {
    _price = v;
    notifyListeners();
  }

  String get condition => _condition;
  set condition(String v) {
    _condition = v;
    notifyListeners();
  }

  String get exchangeType => _exchangeType;
  set exchangeType(String v) {
    _exchangeType = v;
    notifyListeners();
  }

  List<String> get tags => _tags;
  set tags(List<String> v) {
    _tags = v;
    _tagsInput = _tags.join(', ');
    notifyListeners();
  }

  String get tagsInput => _tagsInput;
  set tagsInput(String v) {
    _tagsInput = v;
    _tags = _parseTags(v);
    notifyListeners();
  }

  List<dynamic> get images => _images;
  List<String> get aiTags => _tags;

  List<String> _parseTags(String value) {
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  void setImages(List<dynamic> files) {
    final updated = List<dynamic>.from(_images)..addAll(files);
    _images = updated.take(5).toList();
    notifyListeners();
    runAiTagging();
  }

  void addImage(dynamic file) {
    if (file is! File && file is! Uint8List) return;
    if (_images.length < 5) {
      _images.add(file);
      notifyListeners();
      runAiTagging();
    }
  }

  void removeImageAt(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      notifyListeners();
    }
  }

  void runAiTagging() {
    if (_images.isEmpty) return;
    _aiLoading = true;
    _aiProgress = 0;
    _aiDone = false;
    notifyListeners();
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 60));
      _aiProgress += 4;
      if (_aiProgress >= 100) {
        _aiLoading = false;
        _aiDone = true;
        _title = _title.isEmpty ? 'Casual Denim Jacket' : _title;
        _condition = 'Good';
        _aiProgress = 100;
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    });
  }

  Future<void> publish() async {
    final user = _session.currentUser;
    final sellerName = user == null
        ? 'Me'
        : (user.displayName.trim().isNotEmpty
            ? user.displayName
            : user.email.split('@').first);
    // Soporte para múltiples imágenes
    final listing = Listing(
      id: '', // Se asignará por Firestore
      sellerId: '', // Se asignará en ListingService
      title: _title,
      price: int.tryParse(_price) ?? 0,
      conditionTag: _condition,
      description: _description,
      sellerName: sellerName,
      exchangeType: _exchangeType,
      tags: _tags,
      rating: 0,
      imageName: '',
      createdAt: null,
      soldAt: null,
      imagePath: '',
      imageURLs: const [],
      status: 'active',
      saved: false,
    );
    await _listingService.createListing(listing: listing, images: _images);
    _published = true;
    notifyListeners();
  }

  void resetAfterPublish() {
    _aiLoading = false;
    _aiDone = false;
    _aiProgress = 0;
    _published = false;
    _title = '';
    _images = [];
    _price = '';
    _condition = 'Good';
    _exchangeType = 'sell';
    _tags = [];
    _tagsInput = '';
    notifyListeners();
  }
}

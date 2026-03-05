import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';

class SellViewModel extends ChangeNotifier {
  String? _photoPath;
  bool _aiLoading = false;
  bool _aiDone = false;
  double _aiProgress = 0;
  bool _published = false;

  String _title = '';
  String _description = '';
  String _price = '';
  String _condition = 'Good';
  String _exchangeType = 'sell';
  String _size = '';
  String _color = '';
  String _category = '';
  String _style = '';

  String? get photoPath => _photoPath;
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

  String get size => _size;
  set size(String v) {
    _size = v;
    notifyListeners();
  }

  String get color => _color;
  set color(String v) {
    _color = v;
    notifyListeners();
  }

  String get category => _category;
  set category(String v) {
    _category = v;
    notifyListeners();
  }

  String get style => _style;
  set style(String v) {
    _style = v;
    notifyListeners();
  }

  void setPhotoFromFile(File file) {
    _photoPath = file.path;
    notifyListeners();
    runAiTagging();
  }

  void setPhotoFromUrl(String url) {
    _photoPath = url;
    notifyListeners();
    runAiTagging();
  }

  void runAiTagging() {
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
        _size = 'M';
        _color = 'Blue';
        _category = 'Jackets';
        _style = 'Casual';
        _condition = 'Good';
        _aiProgress = 100;
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    });
  }

  void publish() {
    _published = true;
    notifyListeners();
  }

  void resetAfterPublish() {
    _photoPath = null;
    _aiLoading = false;
    _aiDone = false;
    _aiProgress = 0;
    _published = false;
    _title = '';
    _description = '';
    _price = '';
    _condition = 'Good';
    _exchangeType = 'sell';
    _size = '';
    _color = '';
    _category = '';
    _style = '';
    notifyListeners();
  }

  static String get randomSustainabilityTip =>
      MockData.sustainabilityTips[(DateTime.now().millisecondsSinceEpoch %
          MockData.sustainabilityTips.length)];
}

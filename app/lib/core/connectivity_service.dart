import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityService() {
    Connectivity().onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }
}

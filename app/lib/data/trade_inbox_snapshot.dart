import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TradeInboxSnapshot {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/trade_inbox_snapshot.json');
  }

  static Future<void> persist(List<Map<String, dynamic>> jsonList) async {
    try {
      final file = await _getFile();
      final payload = {
        'list': jsonList,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Use compute isolate to serialize off the main thread as specified in section 7.4
      final serialized = await compute(_serializeJson, payload);
      await file.writeAsString(serialized);
    } catch (e) {
      debugPrint('Error persisting trade inbox snapshot: $e');
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      return json.decode(content) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error loading trade inbox snapshot: $e');
      return null;
    }
  }
}

String _serializeJson(Map<String, dynamic> data) {
  return json.encode(data);
}

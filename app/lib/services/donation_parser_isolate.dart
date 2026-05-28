import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import '../models/listing.dart';

class DonationParserIsolate {
  /// Parses a raw JSON string of donation listings in a native background Isolate.
  /// Returns a Stream that emits the parsed List<Listing> when ready.
  Stream<List<Listing>> parseDonationsStream(String rawJson) {
    final controller = StreamController<List<Listing>>();
    final receivePort = ReceivePort();

    // Listen to the port for results from the spawned Isolate
    receivePort.listen((message) {
      if (message is List) {
        // Map back to Listing models
        final List<Listing> listings = message
            .map((item) => Listing.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        controller.add(listings);
        controller.close();
        receivePort.close();
      } else if (message is String && message.startsWith('ERROR:')) {
        controller.addError(Exception(message));
        controller.close();
        receivePort.close();
      }
    });


    Isolate.spawn(
      _isolateEntry,
      _IsolateData(rawJson, receivePort.sendPort),
    ).catchError((error) {
      controller.addError(error);
      controller.close();
      receivePort.close();
    });

    return controller.stream;
  }

  // The entry point for the background Isolate (must be a top-level or static function)
  static void _isolateEntry(_IsolateData data) {
    try {
      final decoded = json.decode(data.rawJson);
      List<dynamic> list = [];
      if (decoded is Map<String, dynamic> && decoded.containsKey('list')) {
        list = decoded['list'] as List? ?? [];
      } else if (decoded is List) {
        list = decoded;
      }
      
      // Send raw parsed objects back over the SendPort
      data.sendPort.send(list);
    } catch (e) {
      data.sendPort.send('ERROR: ${e.toString()}');
    }
  }
}

class _IsolateData {
  final String rawJson;
  final SendPort sendPort;

  _IsolateData(this.rawJson, this.sendPort);
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:path_provider/path_provider.dart';
import 'vocab_bank.dart';

class SyncService {
  final FlutterP2pConnection _p2p = FlutterP2pConnection();
  bool _isHost = false;
  Function(String)? onStatusUpdate;

  /// Start as host — wait for a client to connect.
  Future<void> startHost() async {
    _isHost = true;
    onStatusUpdate?.call('Waiting for peer…');
    _p2p.startHost();
    _listenForConnections();
  }

  /// Start as client — connect to a host.
  Future<void> startClient() async {
    _isHost = false;
    final peers = await _p2p.discoverPeers();
    if (peers.isEmpty) {
      onStatusUpdate?.call('No peers found');
      return;
    }
    onStatusUpdate?.call('Connecting to ${peers.first.name}…');
    await _p2p.connectToPeer(peers.first.id);
    _listenForConnections();
  }

  void _listenForConnections() {
    _p2p.connectionStream.listen((event) {
      switch (event.type) {
        case ConnectionType.connected:
          onStatusUpdate?.call('Connected');
          if (_isHost) _sendVocabBank();
          break;
        case ConnectionType.data:
          if (!_isHost) _receiveVocabBank(event.data!);
          break;
        case ConnectionType.disconnected:
          onStatusUpdate?.call('Disconnected');
          break;
      }
    });
  }

  Future<void> _sendVocabBank() async {
    onStatusUpdate?.call('Sending vocabulary…');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/vocab_bank.json');
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      _p2p.sendData(utf8.decode(bytes));
    }
  }

  Future<void> _receiveVocabBank(String json) async {
    onStatusUpdate?.call('Receiving vocabulary…');
    try {
      final incoming = (jsonDecode(json) as List)
          .map((e) => VocabEntry.fromJson(e))
          .toList();
      final existing = await VocabBank.load();

      // Merge: deduplicate by word + sourceDocument, keep newest timestamp
      final merged = <String, VocabEntry>{};
      for (final e in [...existing, ...incoming]) {
        final key = '${e.word}|${e.sourceDocument}';
        if (!merged.containsKey(key) ||
            e.savedAt.isAfter(merged[key]!.savedAt)) {
          merged[key] = e;
        }
      }

      await VocabBank.save(merged.values.toList());
      onStatusUpdate?.call('Vocabulary merged (${merged.length} entries)');
    } catch (e) {
      onStatusUpdate?.call('Sync error: $e');
    }
  }

  Future<void> disconnect() async {
    await _p2p.disconnect();
  }
}

import 'package:flutter/material.dart';
import '../services/vocab_bank.dart';
import '../services/anki_export.dart';
import '../services/sync_service.dart';

class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});

  @override
  State<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends State<VocabScreen> {
  List<VocabEntry> _entries = [];
  bool _loading = true;
  final SyncService _sync = SyncService();
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
    _sync.onStatusUpdate = (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => _syncStatus = msg);
      }
    };
  }

  Future<void> _load() async {
    final data = await VocabBank.load();
    setState(() {
      _entries = data;
      _loading = false;
    });
  }

  Future<void> _exportAnki() async {
    final path = await AnkiExport.exportVocabToCSV();
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No words to export.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
    }
  }

  void _startSync() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sync Vocabulary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
              const SizedBox(height: 16),
              if (_syncStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_syncStatus, style: const TextStyle(color: Colors.white70)),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _sync.startHost();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Host'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _sync.startClient();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.wifi),
                      label: const Text('Join'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _sync.disconnect();
                  Navigator.pop(context);
                },
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with another device',
            onPressed: _startSync,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export to Anki CSV',
            onPressed: _exportAnki,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No saved words yet.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final entry = _entries[i];
                    return ListTile(
                      title: Text(entry.word, style: const TextStyle(color: Colors.tealAccent)),
                      subtitle: Text(entry.definition, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(entry.savedAt.toString().substring(0, 10)),
                    );
                  },
                ),
    );
  }
}

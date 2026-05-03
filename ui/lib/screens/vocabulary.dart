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

  @override
  void initState() {
    super.initState();
    _load();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words to export.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $path')),
      );
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
              const SizedBox(height: 12),
              const Text('Share your vocabulary instantly between devices — no internet, no cloud.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showQrCode();
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Show QR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showScanner();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SyncService.shareToClipboard(context);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SyncService.importFromClipboard(context);
                        Navigator.pop(context);
                        _load();
                      },
                      icon: const Icon(Icons.paste),
                      label: const Text('Paste'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scan this QR code on the other device',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              SyncService.buildQrCode(context),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Scan Vocabulary QR')),
          body: SyncService.buildScanner(
            onDetected: (data) async {
              final added = await SyncService.importFromString(data);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(added > 0 ? 'Imported $added new words.' : 'No new words found.')),
                );
                _load();
              }
            },
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

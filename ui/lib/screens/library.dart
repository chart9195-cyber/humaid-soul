import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/vocab_bank.dart';
import '../services/thumbnail_service.dart';
import '../services/recent_documents.dart';
import 'reader.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> _documents = [];
  List<String> _recent = [];
  Map<String, int> _wordCounts = {};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/library.json');
    if (await file.exists()) {
      final list = jsonDecode(await file.readAsString()) as List;
      setState(() {
        _documents = list.cast<String>();
        _removeDeadEntries();
      });
    }
    _updateWordCounts();
    _recent = await RecentDocuments.load();
    setState(() {});
  }

  void _removeDeadEntries() {
    _documents.removeWhere((path) => !File(path).existsSync());
    _saveLibrary();
  }

  Future<void> _saveLibrary() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/library.json');
    await file.writeAsString(jsonEncode(_documents));
  }

  Future<void> _updateWordCounts() async {
    final allWords = await VocabBank.load();
    final counts = <String, int>{};
    for (final doc in _documents) {
      final docName = doc.split('/').last;
      final count = allWords.where((w) => w.sourceDocument == docName).length;
      counts[doc] = count;
    }
    if (mounted) setState(() => _wordCounts = counts);
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path != null && !_documents.contains(path)) {
        setState(() => _documents.add(path));
        await _saveLibrary();
        await _updateWordCounts();
        // Generate thumbnail in background
        ThumbnailService.getThumbnail(path);
      }
    }
  }

  Future<void> _importURL() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import PDF from URL'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Download')),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }
    setState(() => _importing = true);
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final dir = await getApplicationDocumentsDirectory();
      var fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'document.pdf';
      if (!fileName.endsWith('.pdf')) fileName = '$fileName.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      if (!_documents.contains(file.path)) {
        setState(() => _documents.add(file.path));
        await _saveLibrary();
        await _updateWordCounts();
        ThumbnailService.getThumbnail(file.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
    setState(() => _importing = false);
  }

  void _openDocument(String path) async {
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File no longer exists.')));
      _removeDeadEntries();
      return;
    }
    // Track in recent
    await RecentDocuments.add(path);
    _recent = await RecentDocuments.load();
    setState(() {});

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: path)),
    );
    _updateWordCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUMAID SOUL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search all documents',
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(icon: const Icon(Icons.book), tooltip: 'Vocabulary Bank', onPressed: () => Navigator.pushNamed(context, '/vocab')),
          IconButton(icon: const Icon(Icons.dns), tooltip: 'Soul-Packs', onPressed: () => Navigator.pushNamed(context, '/soulpacks')),
          IconButton(icon: const Icon(Icons.link), tooltip: 'Import from URL', onPressed: _importing ? null : _importURL),
          IconButton(icon: const Icon(Icons.add), onPressed: _importing ? null : _importFile),
        ],
      ),
      body: _importing
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('Your Library\nTap + to import a PDF.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView(
                  children: [
                    // Recent section
                    if (_recent.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('RECENT', style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5)),
                      ),
                      ..._recent.take(3).map((path) => _buildListTile(path)),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Divider(color: Colors.white12),
                      ),
                    ],
                    // Full library
                    ..._documents.map((path) => _buildListTile(path)),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/test'),
        label: const Text('Test Engine'),
        icon: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildListTile(String path) {
    final name = path.split('/').last;
    final wordCount = _wordCounts[path] ?? 0;
    return ListTile(
      leading: FutureBuilder<String?>(
        future: ThumbnailService.getThumbnail(path),
        builder: (context, snapshot) {
          final thumbPath = snapshot.data;
          if (thumbPath != null && File(thumbPath).existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(thumbPath), width: 40, height: 52, fit: BoxFit.cover),
            );
          }
          return const Icon(Icons.picture_as_pdf);
        },
      ),
      title: Text(name),
      subtitle: wordCount > 0 ? Text('$wordCount saved words') : null,
      onTap: () => _openDocument(path),
    );
  }
}

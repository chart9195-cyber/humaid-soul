import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../vocab.dart';
import 'reader.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> _documents = [];
  Map<String, int> _wordCounts = {};

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

  Future<void> _importPDF() async {
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
      }
    }
  }

  void _openDocument(String path) async {
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File no longer exists.')),
      );
      _removeDeadEntries();
      return;
    }
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
            icon: const Icon(Icons.book),
            tooltip: 'Vocabulary Bank',
            onPressed: () => Navigator.pushNamed(context, '/vocab'),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _importPDF),
        ],
      ),
      body: _documents.isEmpty
          ? const Center(
              child: Text('Your Library\nTap + to import a PDF.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (_, i) {
                final path = _documents[i];
                final name = path.split('/').last;
                final wordCount = _wordCounts[path] ?? 0;
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(name),
                  subtitle: wordCount > 0 ? Text('$wordCount saved words') : null,
                  onTap: () => _openDocument(path),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/test'),
        label: const Text('Test Engine'),
        icon: const Icon(Icons.search),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'reader.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> _documents = [];

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
      }
    }
  }

  void _openDocument(String path) {
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File no longer exists.')),
      );
      _removeDeadEntries();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUMAID SOUL'),
        actions: [
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
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(name),
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

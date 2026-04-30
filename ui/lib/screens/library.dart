import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'reader.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> _documents = []; // list of file paths

  Future<void> _importPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path != null) {
        setState(() {
          _documents.add(path);
        });
      }
    }
  }

  void _openDocument(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(pdfPath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUMAID SOUL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _importPDF,
          ),
        ],
      ),
      body: _documents.isEmpty
          ? const Center(
              child: Text(
                'Your Library\nTap + to import a PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final path = _documents[index];
                final fileName = path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(fileName),
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

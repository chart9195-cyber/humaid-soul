import 'package:flutter/material.dart';
import '../services/search_service.dart';
import 'reader.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;

  Future<void> _performSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final results = await SearchService.search(query);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _openDocument(String path, int page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(pdfPath: path, initialPage: page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folder Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: 'Enter word to find...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _performSearch,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results yet.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final result = _results[i];
                      final docName = result.documentPath.split('/').last;
                      return ExpansionTile(
                        title: Text(docName),
                        subtitle: Text('Found on ${result.pageNumbers.length} page(s)'),
                        children: result.pageNumbers.take(20).map((p) => ListTile(
                              title: Text('Page $p'),
                              onTap: () => _openDocument(result.documentPath, p),
                            )).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

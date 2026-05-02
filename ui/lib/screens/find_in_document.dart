import 'package:flutter/material.dart';
import '../services/pdf_text_service.dart';

class FindInDocumentScreen extends StatefulWidget {
  final String pdfPath;
  const FindInDocumentScreen({super.key, required this.pdfPath});

  @override
  State<FindInDocumentScreen> createState() => _FindInDocumentScreenState();
}

class _FindInDocumentScreenState extends State<FindInDocumentScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<_Match> _matches = [];
  bool _loading = false;
  bool _loaded = false;
  List<String> _pageTexts = [];

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final service = PdfTextService(widget.pdfPath);
    _pageTexts = await service.getPageTexts();
    setState(() => _loaded = true);
  }

  void _performSearch() {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty || _pageTexts.isEmpty) return;

    setState(() => _loading = true);
    final matches = <_Match>[];
    for (int i = 0; i < _pageTexts.length; i++) {
      final pageText = _pageTexts[i].toLowerCase();
      int start = 0;
      while (start < pageText.length) {
        final index = pageText.indexOf(query, start);
        if (index == -1) break;
        // Extract a snippet around the match
        final snippetStart = (index - 40).clamp(0, pageText.length);
        final snippetEnd = (index + query.length + 40).clamp(0, pageText.length);
        final snippet = _pageTexts[i].substring(snippetStart, snippetEnd);
        final before = _pageTexts[i].substring(snippetStart, index);
        final match = _pageTexts[i].substring(index, index + query.length);
        final after = _pageTexts[i].substring(index + query.length, snippetEnd);
        matches.add(_Match(
          pageNumber: i + 1,
          snippetBefore: before,
          matchText: match,
          snippetAfter: after,
        ));
        start = index + query.length;
        if (matches.length >= 100) break; // limit results
      }
      if (matches.length >= 100) break;
    }
    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find in Document')),
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
                      hintText: 'Search within document...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_loading || !_loaded) ? null : _performSearch,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                      : const Text('Find'),
                ),
              ],
            ),
          ),
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${_matches.length} match(es) found'),
            ),
          Expanded(
            child: _matches.isEmpty
                ? const Center(child: Text('Enter a search term.'))
                : ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (_, i) {
                      final m = _matches[i];
                      return ListTile(
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            children: [
                              TextSpan(text: '...${m.snippetBefore}'),
                              TextSpan(
                                text: m.matchText,
                                style: const TextStyle(
                                  backgroundColor: Colors.teal,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: '${m.snippetAfter}...'),
                            ],
                          ),
                        ),
                        subtitle: Text('Page ${m.pageNumber}'),
                        onTap: () {
                          // Navigate back to reader with initialPage
                          Navigator.pop(context, m.pageNumber);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Match {
  final int pageNumber;
  final String snippetBefore;
  final String matchText;
  final String snippetAfter;
  _Match({
    required this.pageNumber,
    required this.snippetBefore,
    required this.matchText,
    required this.snippetAfter,
  });
}

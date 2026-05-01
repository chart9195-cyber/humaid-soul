import 'dart:collection';
import 'pdf_text_service.dart';
import 'library_service.dart';

class SearchResult {
  final String documentPath;
  final List<int> pageNumbers;
  SearchResult(this.documentPath, this.pageNumbers);
}

class SearchService {
  static Future<List<SearchResult>> search(String word) async {
    final docs = await LibraryService.getDocuments();
    final results = <SearchResult>[];
    for (final docPath in docs) {
      try {
        final textService = PdfTextService(docPath);
        final pageTexts = await textService.getPageTexts();
        final pages = <int>[];
        for (int i = 0; i < pageTexts.length; i++) {
          if (pageTexts[i].toLowerCase().contains(word.toLowerCase())) {
            pages.add(i + 1); // 1‑based page numbers
          }
        }
        if (pages.isNotEmpty) {
          results.add(SearchResult(docPath, pages));
        }
      } catch (_) {
        // Skip documents that can't be read
      }
    }
    return results;
  }
}

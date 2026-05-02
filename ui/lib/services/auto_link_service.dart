import 'package:collection/collection.dart';
import 'pdf_text_service.dart';

class AutoLinkService {
  /// Returns a map of words to their target page numbers (1‑based).
  /// Only processes section references like "Section 2", "Article III", etc.
  static Future<Map<String, int>> buildLinkMap(String pdfPath) async {
    final textService = PdfTextService(pdfPath);
    final pageTexts = await textService.getPageTexts();
    if (pageTexts.isEmpty) return {};

    // Regex patterns
    final sectionRefRegex = RegExp(
      r'\b(Section|Article|Chapter|Part|Clause)\s+([0-9]+(?:\.[0-9]+)*|[IVXLCDM]+)\b',
      caseSensitive: false,
    );

    final headingRegex = RegExp(
      r'^\s*(Section|Article|Chapter|Part|Clause)\s+([0-9]+(?:\.[0-9]+)*|[IVXLCDM]+)\b',
      multiLine: true,
      caseSensitive: false,
    );

    final Map<String, int> linkMap = {};
    final Map<String, int> headingPage = {};

    // 1. Collect heading pages
    for (int i = 0; i < pageTexts.length; i++) {
      final page = i + 1;
      final text = pageTexts[i];
      for (final match in headingRegex.allMatches(text)) {
        final type = match.group(1)!.toLowerCase();
        final id = match.group(2)!.toLowerCase();
        final key = '$type $id';
        headingPage[key] = page;
      }
    }

    // 2. Match references to headings
    for (int i = 0; i < pageTexts.length; i++) {
      final text = pageTexts[i];
      for (final match in sectionRefRegex.allMatches(text)) {
        final type = match.group(1)!.toLowerCase();
        final id = match.group(2)!.toLowerCase();
        final fullMatch = match.group(0)!.trim(); // "Section 4.2"
        final key = '$type $id';
        if (headingPage.containsKey(key)) {
          linkMap[fullMatch] = headingPage[key]!;
        }
      }
    }

    return linkMap;
  }
}

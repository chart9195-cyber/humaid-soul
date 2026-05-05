import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class PdfTextService {
  final String filePath;
  List<String>? _pageTexts;

  PdfTextService(this.filePath);

  /// Returns a list of page texts asynchronously (for use on the main isolate).
  Future<List<String>> getPageTexts() async {
    if (_pageTexts != null) return _pageTexts!;
    final bytes = await File(filePath).readAsBytes();
    final doc = sf_pdf.PdfDocument(inputBytes: bytes);
    final extractor = sf_pdf.PdfTextExtractor(doc);
    final lines = extractor.extractTextLines();

    final map = <int, List<String>>{};
    for (final line in lines) {
      final page = line.pageIndex;
      map.putIfAbsent(page, () => []).add(line.text);
    }
    final totalPages = doc.pages.count;
    _pageTexts = List.generate(totalPages, (i) => (map[i] ?? []).join(' '));
    doc.dispose();
    return _pageTexts!;
  }

  /// Returns the text for a single page (1‑based index).
  Future<String?> getPageText(int pageIndex) async {
    final texts = await getPageTexts();
    if (pageIndex < 0 || pageIndex >= texts.length) return null;
    return texts[pageIndex];
  }

  /// **Synchronous** version designed for use in background isolates.
  /// Reads the PDF directly from disk and extracts all page texts.
  static List<String> getPageTextsSync(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final doc = sf_pdf.PdfDocument(inputBytes: bytes);
    final extractor = sf_pdf.PdfTextExtractor(doc);
    final lines = extractor.extractTextLines();

    final map = <int, List<String>>{};
    for (final line in lines) {
      final page = line.pageIndex;
      map.putIfAbsent(page, () => []).add(line.text);
    }
    final totalPages = doc.pages.count;
    final result = List.generate(totalPages, (i) => (map[i] ?? []).join(' '));
    doc.dispose();
    return result;
  }
}

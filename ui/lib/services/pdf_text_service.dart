import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class PdfTextService {
  final String filePath;
  List<String>? _pageTexts;

  PdfTextService(this.filePath);

  Future<List<String>> getPageTexts() async {
    if (_pageTexts != null) return _pageTexts!;
    final bytes = await File(filePath).readAsBytes();
    final doc = sf_pdf.PdfDocument(inputBytes: bytes);
    final extractor = sf_pdf.PdfTextExtractor(doc);
    final lines = extractor.extractTextLines();

    // Group lines by page index
    final map = <int, List<String>>{};
    for (final line in lines) {
      final page = line.pageIndex;
      map.putIfAbsent(page, () => []).add(line.text);
    }
    final totalPages = doc.pages.length;
    _pageTexts = List.generate(totalPages, (i) => (map[i] ?? []).join(' '));
    doc.dispose();
    return _pageTexts!;
  }

  Future<String?> getPageText(int pageIndex) async {
    final texts = await getPageTexts();
    if (pageIndex < 0 || pageIndex >= texts.length) return null;
    return texts[pageIndex];
  }
}

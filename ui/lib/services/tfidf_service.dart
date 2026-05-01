import 'dart:math';
import 'package:collection/collection.dart';
import 'pdf_text_service.dart';
import 'library_service.dart';

class TfidfService {
  static Future<Map<String, double>> computeTfidf(String docPath) async {
    // 1. Get all document paths
    final allDocs = await LibraryService.getDocuments();
    if (allDocs.isEmpty) return {};

    // 2. Compute term frequency for each document (word counts)
    final docWordCounts = <String, Map<String, int>>{};
    for (final d in allDocs) {
      try {
        final textService = PdfTextService(d);
        final pageTexts = await textService.getPageTexts();
        final fullText = pageTexts.join(' ');
        final words = fullText
            .toLowerCase()
            .split(RegExp(r'\W+'))
            .where((w) => w.length > 2);
        final counts = <String, int>{};
        for (final w in words) {
          counts[w] = (counts[w] ?? 0) + 1;
        }
        docWordCounts[d] = counts;
      } catch (_) {}
    }

    // 3. Compute document frequencies
    final docFreq = <String, int>{};
    for (final counts in docWordCounts.values) {
      for (final word in counts.keys) {
        docFreq[word] = (docFreq[word] ?? 0) + 1;
      }
    }

    final targetCounts = docWordCounts[docPath];
    if (targetCounts == null) return {};

    final totalDocs = docWordCounts.length;
    final totalWordsInDoc = targetCounts.values.sum;

    // 4. Compute TF‑IDF for each word in the target document
    final tfidfScores = <String, double>{};
    for (final word in targetCounts.keys) {
      final tf = targetCounts[word]! / totalWordsInDoc;
      final df = docFreq[word] ?? 1;
      final idf = log(totalDocs / df);
      tfidfScores[word] = tf * idf;
    }

    // 5. Return top 50 scored words
    final sorted = tfidfScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(50));
  }
}

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pdf_text_service.dart';
import 'library_service.dart';

class _TfidfInput {
  final String docPath;
  final List<String> allDocPaths;
  _TfidfInput(this.docPath, this.allDocPaths);
}

class _TfidfOutput {
  final Map<String, double> scores;
  _TfidfOutput(this.scores);
}

_TfidfOutput _computeTfidf(_TfidfInput input) {
  // 1. Get text for all documents
  final docWordCounts = <String, Map<String, int>>{};
  for (final d in input.allDocPaths) {
    try {
      final textService = PdfTextService(d);
      final pageTexts = textService.getPageTextsSync(); // We'll add a sync version
      if (pageTexts == null) continue;
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

  final targetCounts = docWordCounts[input.docPath];
  if (targetCounts == null) return _TfidfOutput({});
  final totalDocs = docWordCounts.length;
  final totalWordsInDoc = targetCounts.values.fold<int>(0, (a, b) => a + b);
  if (totalWordsInDoc == 0) return _TfidfOutput({});

  final docFreq = <String, int>{};
  for (final counts in docWordCounts.values) {
    for (final word in counts.keys) {
      docFreq[word] = (docFreq[word] ?? 0) + 1;
    }
  }

  final tfidfScores = <String, double>{};
  for (final word in targetCounts.keys) {
    final tf = targetCounts[word]! / totalWordsInDoc;
    final df = docFreq[word] ?? 1;
    final idf = log(totalDocs / df);
    tfidfScores[word] = tf * idf;
  }

  final sorted = tfidfScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return _TfidfOutput(Map.fromEntries(sorted.take(50)));
}

class TfidfService {
  static Future<Map<String, double>> computeTfidf(String docPath) async {
    final allDocs = await LibraryService.getDocuments();
    if (allDocs.isEmpty) return {};
    final input = _TfidfInput(docPath, allDocs);
    final output = await compute(_computeTfidf, input);
    return output.scores;
  }
}

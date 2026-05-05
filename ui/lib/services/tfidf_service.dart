import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pdf_text_service.dart';
import 'library_service.dart';

/// Input transferred to the background isolate.
class _TfidfInput {
  final String docPath;
  final List<String> allDocPaths;
  _TfidfInput(this.docPath, this.allDocPaths);
}

/// Output produced by the background isolate.
class _TfidfOutput {
  final Map<String, double> scores;
  _TfidfOutput(this.scores);
}

/// Runs inside a Dart isolate – pure computation, no Flutter dependencies.
_TfidfOutput _computeTfidf(_TfidfInput input) {
  // 1. Read every document and count words
  final docWordCounts = <String, Map<String, int>>{};
  for (final path in input.allDocPaths) {
    try {
      final pageTexts = PdfTextService.getPageTextsSync(path);
      final fullText = pageTexts.join(' ');
      final words = fullText
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 2);
      final counts = <String, int>{};
      for (final w in words) {
        counts[w] = (counts[w] ?? 0) + 1;
      }
      docWordCounts[path] = counts;
    } catch (_) {
      // skip documents that can't be read
    }
  }

  final targetCounts = docWordCounts[input.docPath];
  if (targetCounts == null || targetCounts.isEmpty) return _TfidfOutput({});

  final totalDocs = docWordCounts.length;
  final totalWordsInDoc = targetCounts.values.fold<int>(0, (a, b) => a + b);
  if (totalWordsInDoc == 0) return _TfidfOutput({});

  // 2. Document frequency per word
  final docFreq = <String, int>{};
  for (final counts in docWordCounts.values) {
    for (final word in counts.keys) {
      docFreq[word] = (docFreq[word] ?? 0) + 1;
    }
  }

  // 3. TF‑IDF
  final scores = <String, double>{};
  for (final word in targetCounts.keys) {
    final tf = targetCounts[word]! / totalWordsInDoc;
    final df = (docFreq[word] ?? 1).toDouble();
    final idf = log(totalDocs / df);
    scores[word] = tf * idf;
  }

  // 4. Sort descending and keep top 50
  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return _TfidfOutput(Map.fromEntries(sorted.take(50)));
}

/// Public API – runs TF‑IDF on a background isolate to prevent UI jank.
class TfidfService {
  static Future<Map<String, double>> computeTfidf(String docPath) async {
    final allDocs = await LibraryService.getDocuments();
    if (allDocs.isEmpty) return {};
    final input = _TfidfInput(docPath, allDocs);
    final output = await compute(_computeTfidf, input);
    return output.scores;
  }
}

import 'dart:math';
import '../services/vocab_bank.dart';
import '../widgets/custom_pdf_viewer.dart'; // for WordEntry

class TierHighlighter {
  /// Returns which words in the word map are "Tier 1" (saved multiple times).
  static Future<Set<String>> getTierWords(List<List<WordEntry>> wordMap) async {
    final allSaved = await VocabBank.load();
    // Count occurrences per word
    final counts = <String, int>{};
    for (final entry in allSaved) {
      counts[entry.word.toLowerCase()] = (counts[entry.word.toLowerCase()] ?? 0) + 1;
    }
    // Tier 1 = saved at least twice
    final tierWords = counts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toSet();

    // Extract all words from the word map that match tier words (case insensitive)
    final matched = <String>{};
    for (final page in wordMap) {
      for (final w in page) {
        if (tierWords.contains(w.text.toLowerCase())) {
          matched.add(w.text);
        }
      }
    }
    return matched;
  }
}

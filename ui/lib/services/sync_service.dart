import 'dart:convert';
import 'package:flutter/material.dart';
import 'vocab_bank.dart';

class SyncService {
  /// Encodes the entire vocabulary bank as a base64 JSON string.
  static Future<String> exportToString() async {
    final entries = await VocabBank.load();
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    return base64Encode(utf8.encode(json));
  }

  /// Imports vocabulary from a base64-encoded JSON string.
  /// Merges with existing entries (deduplicates by word + sourceDocument).
  static Future<int> importFromString(String encoded) async {
    try {
      final json = utf8.decode(base64Decode(encoded));
      final incoming = (jsonDecode(json) as List)
          .map((e) => VocabEntry.fromJson(e))
          .toList();
      final existing = await VocabBank.load();

      final merged = <String, VocabEntry>{};
      for (final e in [...existing, ...incoming]) {
        final key = '${e.word}|${e.sourceDocument}';
        if (!merged.containsKey(key) ||
            e.savedAt.isAfter(merged[key]!.savedAt)) {
          merged[key] = e;
        }
      }
      await VocabBank.save(merged.values.toList());
      return merged.length - existing.length;
    } catch (_) {
      return 0;
    }
  }

  /// Copies the encoded vocab string to the clipboard.
  static Future<void> shareToClipboard(BuildContext context) async {
    final data = await exportToString();
    await Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vocabulary copied to clipboard. Paste on the other device.')),
    );
  }

  /// Imports from clipboard and merges.
  static Future<void> importFromClipboard(BuildContext context) async {
    final data = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (data == null || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
      return;
    }
    final added = await importFromString(data);
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $added new words.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new words to import.')),
      );
    }
  }
}

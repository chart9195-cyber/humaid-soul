import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vocab_bank.dart';

class SyncService {
  static Future<String> exportToString() async {
    final entries = await VocabBank.load();
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    return base64Encode(utf8.encode(json));
  }

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

  static Future<void> shareToClipboard(BuildContext context) async {
    final data = await exportToString();
    await Clipboard.setData(ClipboardData(text: data));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vocabulary copied to clipboard. Paste on the other device.')),
      );
    }
  }

  static Future<void> importFromClipboard(BuildContext context) async {
    final data = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (data == null || data.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty.')),
        );
      }
      return;
    }
    final added = await importFromString(data);
    if (context.mounted) {
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
}

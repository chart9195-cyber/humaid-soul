library vocab;

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VocabEntry {
  final String word;
  final String definition;
  final String wordType;
  final List<String> synonyms;
  final String sourceDocument;
  final DateTime savedAt;

  VocabEntry({
    required this.word,
    required this.definition,
    required this.wordType,
    required this.synonyms,
    required this.sourceDocument,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'definition': definition,
        'wordType': wordType,
        'synonyms': synonyms,
        'sourceDocument': sourceDocument,
        'savedAt': savedAt.toIso8601String(),
      };

  factory VocabEntry.fromJson(Map<String, dynamic> json) => VocabEntry(
        word: json['word'] ?? '',
        definition: json['definition'] ?? '',
        wordType: json['wordType'] ?? '',
        synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
        sourceDocument: json['sourceDocument'] ?? '',
        savedAt: DateTime.parse(json['savedAt']),
      );
}

class VocabBank {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vocab_bank.json');
  }

  static Future<List<VocabEntry>> load() async {
    final file = await _getFile();
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List;
    return list.map((e) => VocabEntry.fromJson(e)).toList();
  }

  static Future<void> save(List<VocabEntry> entries) async {
    final file = await _getFile();
    final data = entries.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> add(VocabEntry entry) async {
    final list = await load();
    list.removeWhere((e) =>
        e.word == entry.word && e.sourceDocument == entry.sourceDocument);
    list.insert(0, entry);
    await save(list);
  }

  static Future<int> count() async {
    final list = await load();
    return list.length;
  }
}

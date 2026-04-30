import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'vocab_bank.dart';

class AnkiExport {
  static Future<String?> exportVocabToCSV() async {
    final entries = await VocabBank.load();
    if (entries.isEmpty) return null;
    final buffer = StringBuffer();
    buffer.writeln('Word,Definition,Type,Synonyms,Source');
    for (final e in entries) {
      final syns = e.synonyms.join('; ');
      final escapedDef = e.definition.replaceAll('"', '""');
      final escapedWord = e.word.replaceAll('"', '""');
      buffer.writeln('"$escapedWord","$escapedDef","${e.wordType}","$syns","${e.sourceDocument}"');
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/humaid_soul_export.csv');
    await file.writeAsString(buffer.toString());
    return file.path;
  }
}

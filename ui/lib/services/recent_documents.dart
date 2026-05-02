import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RecentDocuments {
  static const int maxRecent = 5;

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recent.json');
  }

  static Future<List<String>> load() async {
    final file = await _getFile();
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List;
    return list.cast<String>();
  }

  static Future<void> add(String pdfPath) async {
    final recent = await load();
    recent.remove(pdfPath);          // remove if already exists
    recent.insert(0, pdfPath);       // move to top
    if (recent.length > maxRecent) {
      recent.removeRange(maxRecent, recent.length);
    }
    final file = await _getFile();
    await file.writeAsString(jsonEncode(recent));
  }

  static Future<void> remove(String pdfPath) async {
    final recent = await load();
    recent.remove(pdfPath);
    final file = await _getFile();
    await file.writeAsString(jsonEncode(recent));
  }
}

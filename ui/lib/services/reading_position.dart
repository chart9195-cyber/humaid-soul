import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReadingPosition {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/reading_positions.json');
  }

  static Future<Map<String, int>> load() async {
    final file = await _getFile();
    if (!await file.exists()) return {};
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static Future<void> save(String filePath, int page) async {
    final map = await load();
    map[filePath] = page.clamp(1, 100000);
    final file = await _getFile();
    await file.writeAsString(jsonEncode(map));
  }

  static Future<int?> get(String filePath) async {
    final map = await load();
    return map[filePath];
  }
}

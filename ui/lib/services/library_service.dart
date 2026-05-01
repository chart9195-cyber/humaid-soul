import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LibraryService {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/library.json');
  }

  static Future<List<String>> getDocuments() async {
    final file = await _getFile();
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List;
    return list.cast<String>();
  }
}

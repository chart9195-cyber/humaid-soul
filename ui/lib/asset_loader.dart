import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AssetLoader {
  /// Copies the dictionary asset from APK to app documents folder.
  /// Returns the path to the writable file, or null on failure.
  static Future<String?> copyDictionaryToLocal() async {
    const assetPath = 'assets/soul_dict.db.zst';
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/soul_dict.db.zst');

    // If already copied and size > 0, return path.
    if (await file.exists()) {
      final length = await file.length();
      if (length > 0) return file.path;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print("Asset copy failed: $e");
      return null;
    }
  }
}

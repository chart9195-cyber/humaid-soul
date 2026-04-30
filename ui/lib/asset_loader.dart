import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AssetLoader {
  static Future<String?> copyDictionaryToLocal() async {
    const assetPath = 'assets/soul_dict.db.zst';
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/soul_dict.db.zst');

    // Get asset size to validate copy
    final assetData = await rootBundle.load(assetPath);
    final assetBytes = assetData.buffer.asUint8List();

    if (await file.exists()) {
      final existingBytes = await file.readAsBytes();
      if (existingBytes.length == assetBytes.length) {
        return file.path; // already correct
      }
    }

    try {
      await file.writeAsBytes(assetBytes);
      return file.path;
    } catch (e) {
      print("Asset copy failed: $e");
      return null;
    }
  }
}

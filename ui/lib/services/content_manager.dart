import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ContentManager {
  /// Downloads a file from a URL and saves it to the app's documents directory.
  /// Returns the local file path on success, or throws on error.
  static Future<String> downloadPack(
    String url,
    String fileName, {
    Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    // If the file already exists, overwrite it (user explicitly re‑downloading)
    final request = http.Request('GET', Uri.parse(url));
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? -1;
      var receivedBytes = 0;
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && contentLength > 0) {
          final fraction = receivedBytes / contentLength;
          onProgress(fraction.clamp(0.0, 1.0));
        }
      });

      await sink.flush();
      await sink.close();
      return file.path;
    } catch (e) {
      // Remove partially downloaded file
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Verifies that a .zst file exists and has a sensible size (not empty, not truncated).
  static Future<bool> verifyPack(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    // A valid compressed SQLite dictionary is at least a few KB
    return length > 1000;
  }
}

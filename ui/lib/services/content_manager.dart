import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ContentManager {
  static const int maxRetries = 3;
  static const Duration initialTimeout = Duration(seconds: 30);

  static Future<String> downloadPack(
    String url,
    String fileName, {
    Function(double)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(url));
          final response = await client.send(request).timeout(initialTimeout * (attempt + 1));
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
        } finally {
          client.close();
        }
      } catch (e) {
        lastError = e as Exception?;
        attempt++;
        if (attempt < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s ...
          await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
          // Remove incomplete file to restart clean
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    }
    throw lastError ?? Exception('Download failed after $maxRetries attempts');
  }

  static Future<bool> verifyPack(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 1000;
  }
}

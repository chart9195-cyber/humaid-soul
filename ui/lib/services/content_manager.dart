import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ContentManager {
  static const int _maxRetries = 3;
  static const Duration _baseTimeout = Duration(seconds: 30);

  /// Downloads a file from [url] and saves it to the app's documents directory.
  ///
  /// - Retries up to [_maxRetries] times with exponential backoff.
  /// - Enforces a cumulative timeout that grows with each retry.
  /// - Reports progress via [onProgress] (0.0 → 1.0).
  /// - Removes incomplete files after any failure.
  static Future<String> downloadPack(
    String url,
    String fileName, {
    Function(double)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    int attempt = 0;
    Exception? lastError;

    while (attempt < _maxRetries) {
      try {
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(url));
          final streamedResponse = await client
              .send(request)
              .timeout(_baseTimeout * (attempt + 1));

          if (streamedResponse.statusCode != 200) {
            final body = await streamedResponse.stream.bytesToString();
            throw HttpException(
              'Server returned ${streamedResponse.statusCode}: $body',
              uri: Uri.parse(url),
            );
          }

          final contentLength = streamedResponse.contentLength ?? -1;
          var receivedBytes = 0;
          final sink = file.openWrite();

          await streamedResponse.stream.forEach((chunk) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (onProgress != null && contentLength > 0) {
              final fraction = receivedBytes / contentLength;
              onProgress(fraction.clamp(0.0, 1.0));
            }
          });

          await sink.flush();
          await sink.close();
          return file.path; // success
        } finally {
          client.close();
        }
      } on TimeoutException catch (e) {
        lastError = e;
        attempt++;
      } on HttpException catch (e) {
        lastError = e;
        attempt++;
      } catch (e) {
        // unexpected – do not retry
        lastError = Exception('Unexpected download error: $e');
        break;
      }

      if (attempt < _maxRetries) {
        // Exponential backoff: 2s, 4s, 8s
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
        // Remove incomplete file to restart clean
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    throw lastError ?? Exception('Download failed after $_maxRetries attempts');
  }

  /// Returns `true` if the file at [path] exists and is larger than 1 KB.
  static Future<bool> verifyPack(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 1000;
  }
}

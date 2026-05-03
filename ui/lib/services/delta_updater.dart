import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bsdiff/bsdiff.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DeltaUpdater {
  static const String _manifestUrl =
      'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download/versions.json';

  /// Returns artifacts with newer versions than local.
  static Future<Map<String, String>> checkForUpdates(
      Map<String, String> localVersions) async {
    try {
      final response = await http.get(Uri.parse(_manifestUrl));
      if (response.statusCode != 200) return {};
      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      final updates = <String, String>{};
      for (final entry in remote.entries) {
        final artifact = entry.key;
        final remoteVersion = entry.value as String;
        final localVersion = localVersions[artifact];
        if (localVersion == null ||
            remoteVersion.compareTo(localVersion) > 0) {
          updates[artifact] = remoteVersion;
        }
      }
      return updates;
    } catch (_) {
      return {};
    }
  }

  /// Downloads and applies a BSDiff patch.
  static Future<String> applyDelta(
    String artifactName,
    String localPath, {
    Function(double)? onProgress,
  }) async {
    final baseUrl =
        'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download';
    final patchUrl = '$baseUrl/$artifactName.bsdiff';

    // 1. Download patch
    final request = http.Request('GET', Uri.parse(patchUrl));
    final client = http.Client();
    late Uint8List patchBytes;
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('Patch not found');
      final contentLength = response.contentLength ?? -1;
      var received = 0;
      final sink = BytesBuilder();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength);
        }
      });
      patchBytes = sink.toBytes();
    } finally {
      client.close();
    }

    // 2. Read old file
    final oldFile = File(localPath);
    if (!oldFile.existsSync()) throw Exception('Local file not found');
    final oldBytes = await oldFile.readAsBytes();

    // 3. Apply BSDiff patch
    final newBytes = bsdiff.apply(oldBytes, patchBytes);

    // 4. Write patched file
    await oldFile.writeAsBytes(newBytes);
    return localPath;
  }
}

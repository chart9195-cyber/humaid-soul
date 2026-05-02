import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DeltaUpdater {
  static const String _manifestUrl =
      'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download/versions.json';

  /// Returns a map of artifact names that have newer versions than local.
  static Future<Map<String, String>> checkForUpdates(Map<String, String> localVersions) async {
    try {
      final response = await http.get(Uri.parse(_manifestUrl));
      if (response.statusCode != 200) return {};
      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      final updates = <String, String>{};
      for (final entry in remote.entries) {
        final artifact = entry.key;
        final remoteVersion = entry.value as String;
        final localVersion = localVersions[artifact];
        if (localVersion == null || _compareVersions(remoteVersion, localVersion) > 0) {
          updates[artifact] = remoteVersion;
        }
      }
      return updates;
    } catch (_) {
      return {};
    }
  }

  static int _compareVersions(String a, String b) {
    // Simple date‑based comparison: YYYY.MM.DD‑N
    return a.compareTo(b);
  }

  /// Downloads and applies the patch file to update a local artifact.
  static Future<String> applyDelta(String artifactName, String localPath, Function(double) onProgress) async {
    final patchUrl =
        'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download/$artifactName.xdelta';
    final dir = await getApplicationDocumentsDirectory();
    final patchPath = '${dir.path}/$artifactName.patch';

    // Download patch
    final request = http.Request('GET', Uri.parse(patchUrl));
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('Patch not found');
      final contentLength = response.contentLength ?? -1;
      var received = 0;
      final sink = File(patchPath).openWrite();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) onProgress(received / contentLength);
      });
      await sink.close();
    } finally {
      client.close();
    }

    // Apply with xdelta3 (bundled in the app or system)
    final result = await Process.run('xdelta3', ['-d', '-s', localPath, patchPath, localPath]);
    if (result.exitCode != 0) throw Exception('Delta apply failed: ${result.stderr}');

    // Clean up patch file
    await File(patchPath).delete();
    return localPath;
  }
}

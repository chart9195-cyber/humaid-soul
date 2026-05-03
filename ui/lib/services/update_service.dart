import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'content_manager.dart';

class UpdateManifest {
  final String artifactName;
  final String version;
  final String downloadUrl;
  UpdateManifest({
    required this.artifactName,
    required this.version,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const String _manifestUrl =
      'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download/versions.json';
  static const String _downloadBase =
      'https://github.com/chart9195-cyber/humaid-soul/releases/latest/download';

  /// Returns a list of available updates that are newer than what's installed.
  static Future<List<UpdateManifest>> checkForUpdates() async {
    final localVersions = await _loadLocalVersions();
    try {
      final response = await http.get(Uri.parse(_manifestUrl));
      if (response.statusCode != 200) return [];
      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      final updates = <UpdateManifest>[];
      for (final entry in remote.entries) {
        final artifact = entry.key;
        final remoteVersion = entry.value as String;
        final localVersion = localVersions[artifact];
        if (localVersion == null || remoteVersion.compareTo(localVersion) > 0) {
          updates.add(UpdateManifest(
            artifactName: artifact,
            version: remoteVersion,
            downloadUrl: '$_downloadBase/$artifact',
          ));
        }
      }
      return updates;
    } catch (_) {
      return [];
    }
  }

  /// Downloads and applies an update to a local artifact.
  static Future<void> applyUpdate(
    UpdateManifest update, {
    Function(double)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${update.artifactName}';
    await ContentManager.downloadPack(
      update.downloadUrl,
      update.artifactName,
      onProgress: onProgress,
    );
    // Update local version record
    final versions = await _loadLocalVersions();
    versions[update.artifactName] = update.version;
    await _saveLocalVersions(versions);
  }

  static Future<Map<String, String>> _loadLocalVersions() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/versions.json');
    if (!await file.exists()) return {};
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  static Future<void> _saveLocalVersions(Map<String, String> versions) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/versions.json');
    await file.writeAsString(jsonEncode(versions));
  }

  /// Records the initial version of a local artifact (call after first install).
  static Future<void> recordInitialVersion(
    String artifactName,
    String version,
  ) async {
    final versions = await _loadLocalVersions();
    if (!versions.containsKey(artifactName)) {
      versions[artifactName] = version;
      await _saveLocalVersions(versions);
    }
  }
}

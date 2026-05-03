import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VoiceModel {
  final String id;
  final String displayName;
  final String language;
  final String fileName;
  final String tokensName;
  final String dataName;
  final String downloadUrl;
  final int approxSizeMB;
  bool downloaded;
  bool active;

  VoiceModel({
    required this.id,
    required this.displayName,
    required this.language,
    required this.fileName,
    required this.tokensName,
    this.dataName = '',
    required this.downloadUrl,
    required this.approxSizeMB,
    this.downloaded = false,
    this.active = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'language': language,
        'fileName': fileName,
        'tokensName': tokensName,
        'dataName': dataName,
        'downloadUrl': downloadUrl,
        'approxSizeMB': approxSizeMB,
        'downloaded': downloaded,
        'active': active,
      };

  factory VoiceModel.fromJson(Map<String, dynamic> json) => VoiceModel(
        id: json['id'] ?? '',
        displayName: json['displayName'] ?? '',
        language: json['language'] ?? 'en',
        fileName: json['fileName'] ?? '',
        tokensName: json['tokensName'] ?? 'tokens.txt',
        dataName: json['dataName'] ?? '',
        downloadUrl: json['downloadUrl'] ?? '',
        approxSizeMB: json['approxSizeMB'] ?? 50,
        downloaded: json['downloaded'] ?? false,
        active: json['active'] ?? false,
      );
}

class VoicePackManager {
  static const String _releaseBase =
      'https://github.com/chart9195-cyber/humaid-soul/releases/download/v1.0.0-voices';

  static final List<VoiceModel> _defaultModels = [
    VoiceModel(
      id: 'amy', displayName: 'Amy (F)', language: 'en',
      fileName: 'amy.onnx', tokensName: 'tokens.txt',
      dataName: 'espeak-ng-data',
      downloadUrl: '$_releaseBase/amy.zip', approxSizeMB: 52,
    ),
    VoiceModel(
      id: 'john', displayName: 'John (M)', language: 'en',
      fileName: 'john.onnx', tokensName: 'tokens.txt',
      dataName: 'espeak-ng-data',
      downloadUrl: '$_releaseBase/john.zip', approxSizeMB: 52,
    ),
    VoiceModel(
      id: 'norman', displayName: 'Norman (M)', language: 'en',
      fileName: 'norman.onnx', tokensName: 'tokens.txt',
      dataName: 'espeak-ng-data',
      downloadUrl: '$_releaseBase/norman.zip', approxSizeMB: 52,
    ),
    VoiceModel(
      id: 'kristin', displayName: 'Kristin (F)', language: 'en',
      fileName: 'kristin.onnx', tokensName: 'tokens.txt',
      dataName: 'espeak-ng-data',
      downloadUrl: '$_releaseBase/kristin.zip', approxSizeMB: 52,
    ),
  ];

  static Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/voice_packs.json');
  }

  static Future<List<VoiceModel>> load() async {
    final file = await _configFile();
    if (!await file.exists()) {
      await save(_defaultModels);
      return _defaultModels;
    }
    final list = jsonDecode(await file.readAsString()) as List;
    return list.map((e) => VoiceModel.fromJson(e)).toList();
  }

  static Future<void> save(List<VoiceModel> models) async {
    final file = await _configFile();
    await file.writeAsString(jsonEncode(models.map((m) => m.toJson()).toList()));
  }

  static Future<void> markDownloaded(String modelId) async {
    final models = await load();
    final model = models.firstWhere((m) => m.id == modelId);
    model.downloaded = true;
    await save(models);
  }

  static Future<void> setActive(String modelId, bool active) async {
    final models = await load();
    for (final m in models) { m.active = false; }
    final model = models.firstWhere((m) => m.id == modelId);
    model.active = active;
    await save(models);
  }

  static Future<VoiceModel?> getActive() async {
    final models = await load();
    try { return models.firstWhere((m) => m.active); } catch (_) { return null; }
  }

  /// Returns the directory where voice model files are stored.
  static Future<String> getModelDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}

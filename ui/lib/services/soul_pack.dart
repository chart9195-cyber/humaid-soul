import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SoulPack {
  final String name;
  final String domain;
  final String fileName; // e.g., "medical.db.zst"
  final String description;
  final int wordCount;
  bool active;

  SoulPack({
    required this.name,
    required this.domain,
    required this.fileName,
    required this.description,
    required this.wordCount,
    this.active = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'domain': domain,
        'fileName': fileName,
        'description': description,
        'wordCount': wordCount,
        'active': active,
      };

  factory SoulPack.fromJson(Map<String, dynamic> json) => SoulPack(
        name: json['name'] ?? '',
        domain: json['domain'] ?? '',
        fileName: json['fileName'] ?? '',
        description: json['description'] ?? '',
        wordCount: json['wordCount'] ?? 0,
        active: json['active'] ?? false,
      );
}

class SoulPackManager {
  static Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/soul_packs.json');
  }

  static Future<List<SoulPack>> loadPacks() async {
    final file = await _getConfigFile();
    if (!await file.exists()) {
      // Return built-in packs as defaults
      return _defaultPacks();
    }
    final list = jsonDecode(await file.readAsString()) as List;
    return list.map((e) => SoulPack.fromJson(e)).toList();
  }

  static Future<void> savePacks(List<SoulPack> packs) async {
    final file = await _getConfigFile();
    await file.writeAsString(jsonEncode(packs.map((p) => p.toJson()).toList()));
  }

  static Future<void> setActive(String domain, bool active) async {
    final packs = await loadPacks();
    for (final p in packs) {
      p.active = (p.domain == domain) ? active : p.active;
    }
    await savePacks(packs);
  }

  static Future<SoulPack?> getActivePack() async {
    final packs = await loadPacks();
    return packs.cast<SoulPack?>().firstWhere(
          (p) => p!.active,
          orElse: () => null,
        );
  }

  static List<SoulPack> _defaultPacks() {
    return [
      SoulPack(
        name: 'Medical Terminology',
        domain: 'medical',
        fileName: 'medical.db.zst',
        description: 'Clinical terms, anatomy, pharmacology',
        wordCount: 12000,
        active: false,
      ),
      SoulPack(
        name: 'Legal Terminology',
        domain: 'legal',
        fileName: 'legal.db.zst',
        description: 'Contracts, statutes, court terminology',
        wordCount: 8500,
        active: false,
      ),
      SoulPack(
        name: 'General (WordNet)',
        domain: 'general',
        fileName: 'soul_dict.db.zst',
        description: 'Standard English dictionary',
        wordCount: 140000,
        active: true,
      ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/soul_pack.dart';
import '../services/content_manager.dart';
import '../services/update_service.dart';
import '../core_bridge.dart';

class SoulPackScreen extends StatefulWidget {
  const SoulPackScreen({super.key});

  @override
  State<SoulPackScreen> createState() => _SoulPackScreenState();
}

class _SoulPackScreenState extends State<SoulPackScreen> {
  List<SoulPack> _packs = [];
  bool _loading = true;
  Map<String, double> _downloadProgress = {};
  bool _checkingUpdates = false;

  static const String _baseUrl =
      'https://github.com/chart9195-cyber/humaid-soul/releases/download/v1.0.0-soulpacks';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packs = await SoulPackManager.loadPacks();
    setState(() {
      _packs = packs;
      _loading = false;
    });
  }

  Future<String> _docDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<bool> _isPackDownloaded(SoulPack pack) async {
    final path = '${await _docDir()}/${pack.fileName}';
    return File(path).exists();
  }

  Future<void> _togglePack(SoulPack pack) async {
    if (!pack.active) {
      final downloaded = await _isPackDownloaded(pack);
      if (!downloaded) {
        final shouldDownload = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Download ${pack.name}?'),
            content: const Text('This domain dictionary needs to be downloaded first. (~5 MB)'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
            ],
          ),
        );
        if (shouldDownload != true) return;
        if (!mounted) return;
        final success = await _downloadPack(pack);
        if (!success) return;
      }
      final packPath = '${await _docDir()}/${pack.fileName}';
      final bridge = CoreBridge();
      final ok = bridge.loadDomainDictionary(packPath);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load domain dictionary')),
          );
        }
        return;
      }
    } else {
      final bridge = CoreBridge();
      bridge.loadDomainDictionary(null);
    }

    await SoulPackManager.setActive(pack.domain, !pack.active);
    _load();
  }

  Future<bool> _downloadPack(SoulPack pack) async {
    final url = '$_baseUrl/${pack.fileName}';
    setState(() => _downloadProgress[pack.domain] = 0.0);
    try {
      await ContentManager.downloadPack(
        url,
        pack.fileName,
        onProgress: (p) => setState(() => _downloadProgress[pack.domain] = p),
      );
      setState(() => _downloadProgress[pack.domain] = 1.0);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
      setState(() => _downloadProgress.remove(pack.domain));
      return false;
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdates = true);
    final updates = await UpdateService.checkForUpdates();
    if (!mounted) return;
    setState(() => _checkingUpdates = false);

    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Soul‑Packs are up to date.')),
      );
      return;
    }

    // Show a dialog listing available updates
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Updates Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: updates.map((u) => ListTile(
            title: Text(u.artifactName),
            subtitle: Text('Version ${u.version}'),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final update in updates) {
                await UpdateService.applyUpdate(update,
                  onProgress: (p) {
                    // Could show a cumulative progress indicator
                  },
                );
              }
              _load(); // refresh the pack list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated ${updates.length} pack(s).')),
              );
            },
            child: const Text('Update All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soul-Packs'),
        actions: [
          IconButton(
            icon: _checkingUpdates
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.system_update),
            tooltip: 'Check for updates',
            onPressed: _checkingUpdates ? null : _checkForUpdates,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _packs.length,
              itemBuilder: (_, i) {
                final pack = _packs[i];
                final progress = _downloadProgress[pack.domain];
                final isDownloading = progress != null && progress < 1.0;

                return FutureBuilder<bool>(
                  future: _isPackDownloaded(pack),
                  builder: (context, snapshot) {
                    final isDownloaded = snapshot.data ?? false;
                    return SwitchListTile(
                      title: Text(pack.name, style: const TextStyle(color: Colors.tealAccent)),
                      subtitle: isDownloading
                          ? LinearProgressIndicator(value: progress)
                          : Text(
                              '${pack.description}\n${pack.wordCount} terms${isDownloaded ? " (downloaded)" : " (not downloaded)"}',
                            ),
                      value: pack.active,
                      onChanged: isDownloading ? null : (_) => _togglePack(pack),
                    );
                  },
                );
              },
            ),
    );
  }
}

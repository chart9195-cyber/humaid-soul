import 'dart:io';
import 'package:flutter/material.dart';
import '../services/voice_pack_manager.dart';
import '../services/tts_service.dart';
import '../services/content_manager.dart';

class VoiceSoulScreen extends StatefulWidget {
  final TtsService tts;
  const VoiceSoulScreen({super.key, required this.tts});

  @override
  State<VoiceSoulScreen> createState() => _VoiceSoulScreenState();
}

class _VoiceSoulScreenState extends State<VoiceSoulScreen> {
  List<VoiceModel> _models = [];
  bool _loading = true;
  String? _downloadingId;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final models = await VoicePackManager.load();
    setState(() { _models = models; _loading = false; });
  }

  /// Returns true if all required model files exist locally.
  Future<bool> _isDownloaded(VoiceModel model) async {
    final dir = await VoicePackManager.getModelDir();
    return File('${dir}/${model.fileName}').existsSync() &&
           File('${dir}/tokens.txt').existsSync();
  }

  Future<void> _downloadAndActivate(VoiceModel model) async {
    // Check if already downloaded
    final already = await _isDownloaded(model);
    if (already) {
      await _activateVoice(model);
      return;
    }

    setState(() { _downloadingId = model.id; _downloadProgress = 0.0; });

    try {
      final dir = await VoicePackManager.getModelDir();
      // Download the zip
      final zipPath = await ContentManager.downloadPack(
        model.downloadUrl,
        '${model.id}_voice.zip',
        onProgress: (p) => setState(() => _downloadProgress = p),
      );

      // Extract (using system unzip)
      final result = await Process.run('unzip', ['-o', zipPath, '-d', dir]);
      if (result.exitCode != 0) throw Exception('Unzip failed');

      // Clean up zip
      await File(zipPath).delete();

      await VoicePackManager.markDownloaded(model.id);
      await _activateVoice(model);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      setState(() { _downloadingId = null; _downloadProgress = 0.0; });
    }
  }

  Future<void> _activateVoice(VoiceModel model) async {
    final ok = await widget.tts.loadPiperVoice(model);
    if (ok) {
      await VoicePackManager.setActive(model.id, true);
      _load();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load voice model')),
        );
      }
    }
  }

  void _useSystem() {
    widget.tts.useSystemEngine();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeSystem = !widget.tts.isPiperLoaded;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Soul')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('System TTS',
                      style: TextStyle(color: Colors.tealAccent)),
                  subtitle: const Text('Built‑in device voice (always available)'),
                  value: activeSystem,
                  onChanged: (_) => _useSystem(),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Piper Neural Voices (offline)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                     color: Colors.white70)),
                ),
                ..._models.map((model) {
                  final isActive = widget.tts.isPiperLoaded &&
                      widget.tts.piperModelId == model.id;
                  final isDownloading = _downloadingId == model.id;

                  return FutureBuilder<bool>(
                    future: _isDownloaded(model),
                    builder: (ctx, snap) {
                      final downloaded = snap.data ?? model.downloaded;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(model.displayName,
                              style: const TextStyle(color: Colors.tealAccent)),
                          subtitle: isDownloading
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(value: _downloadProgress),
                                    const SizedBox(height: 4),
                                    Text('Downloading… ${(_downloadProgress * 100).round()}%',
                                        style: const TextStyle(fontSize: 11)),
                                  ],
                                )
                              : Text(
                                  '${model.language.toUpperCase()} · ~${model.approxSizeMB} MB'
                                  '${downloaded ? " · downloaded" : " · tap to download"}',
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                          trailing: isActive
                              ? const Icon(Icons.check_circle, color: Colors.tealAccent)
                              : isDownloading
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : TextButton(
                                      onPressed: () => _downloadAndActivate(model),
                                      child: Text(downloaded ? 'ACTIVATE' : 'DOWNLOAD'),
                                    ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/voice_pack_manager.dart';
import '../services/tts_service.dart';

class VoiceSoulScreen extends StatefulWidget {
  final TtsService tts;
  const VoiceSoulScreen({super.key, required this.tts});

  @override
  State<VoiceSoulScreen> createState() => _VoiceSoulScreenState();
}

class _VoiceSoulScreenState extends State<VoiceSoulScreen> {
  List<VoiceModel> _models = [];
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final models = await VoicePackManager.load();
    setState(() {
      _models = models;
      _loading = false;
    });
  }

  Future<void> _downloadAndActivate(VoiceModel model) async {
    setState(() => _downloading = true);
    try {
      // Download model file and tokens file from GitHub Releases
      // For now we assume the user has manually placed them;
      // a full download UI could be added using ContentManager.
      // We'll mark as downloaded and load.
      await VoicePackManager.markDownloaded(model.id);
      final ok = await widget.tts.loadPiperVoice(model);
      if (ok) {
        await VoicePackManager.setActive(model.id, true);
        _load();
      }
    } finally {
      setState(() => _downloading = false);
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
                  title: const Text('System TTS', style: TextStyle(color: Colors.tealAccent)),
                  subtitle: const Text('Built‑in device voice (always available)'),
                  value: activeSystem,
                  onChanged: (_) => _useSystem(),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Piper Neural Voices (offline)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                ),
                ..._models.map((model) {
                  final isActive = widget.tts.isPiperLoaded &&
                      widget.tts.piperModelId == model.id;
                  return SwitchListTile(
                    title: Text(model.displayName, style: const TextStyle(color: Colors.tealAccent)),
                    subtitle: Text('${model.language.toUpperCase()} · ~${model.approxSizeMB} MB'),
                    value: isActive,
                    onChanged: _downloading ? null : (_) => _downloadAndActivate(model),
                    secondary: _downloading && isActive
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                        : null,
                  );
                }),
              ],
            ),
    );
  }
}

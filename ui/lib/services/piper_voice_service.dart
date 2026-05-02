import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'voice_pack_manager.dart';

class PiperVoiceService {
  OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;
  bool _playing = false;
  String? _currentModelId;

  Function()? onComplete;
  Function(String)? onError;

  bool get isLoaded => _loaded;
  bool get isPlaying => _playing;
  String? get currentModelId => _currentModelId;

  Future<bool> loadVoice(VoiceModel model) async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      final modelPath = '${dir.path}/${model.fileName}';
      final tokensPath = '${dir.path}/${model.tokensName}';
      final dataDir = model.dataName.isNotEmpty ? '${dir.path}/${model.dataName}' : '';

      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        onError?.call('Model files missing. Please download first.');
        return false;
      }

      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          model: modelPath,
          tokens: tokensPath,
          dataDir: dataDir.isNotEmpty ? dataDir : null,
          provider: 'cpu',
          numThreads: 2,
        ),
      );

      _tts = OfflineTts(config);
      _loaded = true;
      _currentModelId = model.id;
      await VoicePackManager.setActive(model.id, true);
      return true;
    } catch (e) {
      onError?.call('Sherpa voice load failed: $e');
      return false;
    }
  }

  Future<void> speak(String text) async {
    if (!_loaded || _tts == null) return;
    try {
      if (_playing) await stop();
      _playing = true;

      final Uint8List? audio = await _tts!.generate(text: text);
      if (audio == null) {
        _playing = false;
        onError?.call('Voice synthesis returned no audio');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final outFile = File('${tempDir.path}/piper_speech.wav');
      await outFile.writeAsBytes(audio);

      await _player.setFilePath(outFile.path);
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _playing = false;
          onComplete?.call();
        }
      });
      await _player.play();
    } catch (e) {
      _playing = false;
      onError?.call('Sherpa synthesis failed: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
    _tts = null;
  }
}

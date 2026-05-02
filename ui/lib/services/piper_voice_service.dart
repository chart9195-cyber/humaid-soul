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
      final dataDir =
          model.dataName.isNotEmpty ? '${dir.path}/${model.dataName}' : '';

      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        onError?.call('Model files missing. Please download first.');
        return false;
      }

      // Correctly nested API: OfflineTtsConfig ➜ OfflineTtsModelConfig ➜ OfflineTtsVitsModelConfig
      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          vits: OfflineTtsVitsModelConfig(
            model: modelPath,
            tokens: tokensPath,
            dataDir: dataDir.isNotEmpty ? dataDir : null,
          ),
          numThreads: 2,
          provider: 'cpu',
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

      // generate() returns GeneratedAudio synchronously
      final GeneratedAudio audio = _tts!.generate(text: text);
      final Float32List samples = audio.samples;
      final int sampleRate = audio.sampleRate;

      // Convert float32 PCM to a 16‑bit WAV file
      final Uint8List wavBytes = _encodeWav16(samples, sampleRate);

      final tempDir = await getTemporaryDirectory();
      final outFile = File('${tempDir.path}/piper_speech.wav');
      await outFile.writeAsBytes(wavBytes);

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

  /// Encode mono Float32List samples (range -1.0 … 1.0) into a 16‑bit PCM WAV.
  Uint8List _encodeWav16(Float32List samples, int sampleRate) {
    final int numSamples = samples.length;
    final int dataSize = numSamples * 2; // 16‑bit = 2 bytes per sample
    final int fileSize = 44 + dataSize;
    final ByteData bytes = ByteData(fileSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // 'W'
    bytes.setUint8(9, 0x41); // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // fmt sub‑chunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little);          // sub‑chunk size
    bytes.setUint16(20, 1, Endian.little);           // PCM format
    bytes.setUint16(22, 1, Endian.little);           // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little);           // block align
    bytes.setUint16(34, 16, Endian.little);          // bits per sample

    // data sub‑chunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final int sample = (samples[i] * 32767).clamp(-32768, 32767).round();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
    // OfflineTts uses free(), not dispose()
    _tts?.free();
    _tts = null;
  }
}

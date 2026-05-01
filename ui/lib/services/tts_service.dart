import 'package:flutter_kokoro_tts/flutter_kokoro_tts.dart';

class TtsService {
  final KokoroTts _tts = KokoroTts();
  bool _initialized = false;
  bool _speaking = false;
  Function(String)? onError;

  TtsService({this.onError});

  bool get isSpeaking => _speaking;
  bool get isAvailable => true; // always available after init

  Future<bool> init() async {
    if (_initialized) return true;
    try {
      await _tts.initialize(
        onProgress: (progress, status) {
          // Optional: notify UI of model download progress
          // print('Kokoro init: $status (${(progress * 100).round()}%)');
        },
      );
      _initialized = true;
    } catch (e) {
      onError?.call('Kokoro init failed: $e');
    }
    return _initialized;
  }

  Future<void> speak(String text) async {
    if (!_initialized) return;
    if (_speaking) await stop();
    _speaking = true;
    try {
      final audio = await _tts.generate(
        text,
        voice: 'Bella',
        speed: 1.0,
      );
      // Kokoro returns Float32List; playback requires a separate audio plugin.
      // For a self-contained solution, we'll use the device's built-in player
      // via a simple WAV writer and the system player. For now, we'll stub this.
      // Full integration will be completed in the next iteration.
    } catch (e) {
      onError?.call('Speech generation failed: $e');
    }
    _speaking = false;
  }

  Future<void> stop() async {
    _speaking = false;
    // Kokoro does not support stop mid-generation yet.
  }

  Future<void> dispose() async {
    await _tts.dispose();
  }
}

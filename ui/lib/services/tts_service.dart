import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;
  Function(String)? onError;
  Function()? onComplete;

  TtsService({this.onError, this.onComplete});

  bool get isSpeaking => _speaking;
  bool get isAvailable => _initialized;

  void setCompletionHandler(Function()? handler) {
    onComplete = handler;
    _tts.setCompletionHandler(() {
      _speaking = false;
      onComplete?.call();
    });
  }

  Future<bool> init() async {
    if (_initialized) return true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() => _speaking = true);
      _tts.setErrorHandler((msg) {
        _speaking = false;
        onError?.call(msg);
      });

      _initialized = true;
    } catch (e) {
      onError?.call('TTS init failed: $e');
    }
    return _initialized;
  }

  Future<void> speak(String text) async {
    if (!_initialized) return;
    if (_speaking) await stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
    _speaking = false;
  }

  Future<void> dispose() async {
    await stop();
  }
}

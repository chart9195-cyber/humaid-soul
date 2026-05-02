import 'package:flutter_tts/flutter_tts.dart';
import 'piper_voice_service.dart';
import 'voice_pack_manager.dart';

enum TtsEngine { system, piper }

class TtsService {
  final FlutterTts _systemTts = FlutterTts();
  PiperVoiceService? _piper;

  bool _initialized = false;
  bool _speaking = false;
  TtsEngine _engine = TtsEngine.system;

  Function(String)? onError;
  Function()? onComplete;

  TtsService({this.onError, this.onComplete});

  bool get isSpeaking => _speaking;
  bool get isAvailable => _initialized;
  TtsEngine get engine => _engine;
  bool get isPiperLoaded => _piper?.isLoaded ?? false;
  String? get piperModelId => _piper?.currentModelId;

  void setCompletionHandler(Function()? handler) {
    onComplete = handler;
    _systemTts.setCompletionHandler(() {
      _speaking = false;
      onComplete?.call();
    });
  }

  Future<bool> init() async {
    if (_initialized) return true;
    try {
      await _systemTts.setLanguage('en-US');
      await _systemTts.setSpeechRate(0.5);
      await _systemTts.setVolume(1.0);
      await _systemTts.setPitch(1.0);
      _systemTts.setStartHandler(() => _speaking = true);
      _systemTts.setErrorHandler((msg) {
        _speaking = false;
        onError?.call(msg);
      });
      _initialized = true;
    } catch (e) { onError?.call('TTS init: $e'); }
    return _initialized;
  }

  Future<bool> loadPiperVoice(VoiceModel model) async {
    _piper ??= PiperVoiceService();
    _piper!.onError = onError;
    _piper!.onComplete = () {
      _speaking = false;
      onComplete?.call();
    };
    final ok = await _piper!.loadVoice(model);
    if (ok) _engine = TtsEngine.piper;
    return ok;
  }

  void useSystemEngine() {
    _engine = TtsEngine.system;
  }

  Future<void> speak(String text) async {
    if (_engine == TtsEngine.piper && _piper != null && _piper!.isLoaded) {
      await _piper!.speak(text);
      _speaking = true;
    } else {
      if (_speaking) await stop();
      await _systemTts.speak(text);
      _speaking = true;
    }
  }

  Future<void> stop() async {
    if (_piper != null) await _piper!.stop();
    await _systemTts.stop();
    _speaking = false;
  }

  Future<void> dispose() async {
    await stop();
    await _piper?.dispose();
  }
}

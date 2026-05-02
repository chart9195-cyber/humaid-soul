import 'pdf_text_service.dart';
import 'tts_service.dart';

enum PlaybackState { idle, playing, paused }

class ContinuousTtsController {
  final PdfTextService textService;
  final TtsService tts;
  final int totalPages;
  final Function(int page) onPageChange;
  final Function() onFinished;

  int _currentPage = 1;
  PlaybackState _state = PlaybackState.idle;

  ContinuousTtsController({
    required this.textService,
    required this.tts,
    required this.totalPages,
    required this.onPageChange,
    required this.onFinished,
  });

  PlaybackState get state => _state;
  int get currentPage => _currentPage;

  Future<void> start() async {
    if (_state == PlaybackState.playing) return;
    _state = PlaybackState.playing;
    await _readCurrentPage();
  }

  Future<void> pause() async {
    if (_state != PlaybackState.playing) return;
    await tts.stop();
    _state = PlaybackState.paused;
  }

  Future<void> resume() async {
    if (_state != PlaybackState.paused) return;
    _state = PlaybackState.playing;
    await _readCurrentPage();
  }

  Future<void> stop() async {
    await tts.stop();
    _state = PlaybackState.idle;
  }

  Future<void> _readCurrentPage() async {
    if (_state != PlaybackState.playing) return;
    final text = await textService.getPageText(_currentPage - 1);
    if (text == null || text.trim().isEmpty) {
      await _advancePage();
      return;
    }
    onPageChange(_currentPage);
    await tts.speak(text);

    // Wait for TTS completion (the handler will advance)
    // flutter_tts has setCompletionHandler, but we use a polling approach? Better to wrap.
    // We'll set the completion handler before speaking.
  }

  Future<void> _advancePage() async {
    if (_currentPage < totalPages) {
      _currentPage++;
      await _readCurrentPage();
    } else {
      _state = PlaybackState.idle;
      onFinished();
    }
  }

  void onTtsComplete() {
    if (_state == PlaybackState.playing) {
      _advancePage();
    }
  }
}

import 'package:flutter/material.dart';
import '../core_bridge.dart';
import '../widgets/custom_pdf_viewer.dart';
import '../widgets/tier_overlay_painter.dart';
import '../widgets/auto_link_painter.dart';
import '../services/vocab_bank.dart';
import '../services/pdf_text_service.dart';
import '../services/tts_service.dart';
import '../services/tier_highlighter.dart';
import '../services/reading_position.dart';
import '../services/auto_link_service.dart';
import 'dart:convert';
import 'dart:math';

enum PlaybackState { idle, playing, paused }

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  final int? initialPage;
  const ReaderScreen({super.key, required this.pdfPath, this.initialPage});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _tappedWord;
  Map<String, dynamic>? _entry;
  Offset? _hudPosition;
  final CoreBridge _bridge = CoreBridge();
  bool _wordMapLoading = true;
  DateTime _lastTapTime = DateTime(2000);
  bool _rulerOn = false;
  bool _focusModeOn = false;
  bool _autoLinkOn = false;
  String _sourceDocName = '';

  String? _ghostWord;
  String? _ghostDefinition;
  Offset? _ghostPosition;
  Set<String> _tierWords = {};

  final TtsService _tts = TtsService();
  bool _ttsAvailable = false;

  final GlobalKey<CustomPdfViewerState> _viewerKey = GlobalKey<CustomPdfViewerState>();

  List<Rect> _tierRects = [];
  List<Rect> _linkRects = [];
  Map<String, int> _linkMap = {};

  // Continuous TTS
  PlaybackState _playbackState = PlaybackState.idle;
  int _continuousCurrentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _sourceDocName = widget.pdfPath.split('/').last;
    _bridge.load();
    _tts.onError = (m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    _tts.init().then((ok) => setState(() => _ttsAvailable = ok));
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    if (widget.initialPage != null && _viewerKey.currentState != null) {
      _viewerKey.currentState!.jumpToPage(widget.initialPage!);
    }
  }

  void _onWordMapReady() async {
    setState(() => _wordMapLoading = false);
    final viewerState = _viewerKey.currentState;
    if (viewerState != null && viewerState.isWordMapReady) {
      _totalPages = viewerState.wordMap.length;
      final tier = await TierHighlighter.getTierWords(viewerState.wordMap);
      if (mounted) {
        setState(() => _tierWords = tier);
        _updateTierRects();
        if (_autoLinkOn) _computeAutoLinks();
      }
    }
  }

  void _updateTierRects() {
    final viewerState = _viewerKey.currentState;
    if (viewerState != null && viewerState.isWordMapReady) {
      setState(() {
        _tierRects = viewerState.getTierRects(_tierWords);
      });
    }
  }

  void _onPageChanged() {
    _updateTierRects();
    if (_autoLinkOn) {
      _updateLinkRects();
    }
  }

  void _computeAutoLinks() async {
    final linkMap = await AutoLinkService.buildLinkMap(widget.pdfPath);
    if (!mounted) return;
    setState(() {
      _linkMap = linkMap;
      _updateLinkRects();
    });
  }

  void _updateLinkRects() {
    final viewerState = _viewerKey.currentState;
    if (viewerState != null && viewerState.isWordMapReady) {
      setState(() {
        _linkRects = viewerState.getLinkRects(_linkMap.keys.toSet());
      });
    }
  }

  void _toggleAutoLink() {
    setState(() {
      _autoLinkOn = !_autoLinkOn;
      if (_autoLinkOn) {
        if (_linkMap.isEmpty) _computeAutoLinks();
      } else {
        _linkRects = [];
      }
    });
  }

  void _onAutoLinkTap(int targetPage) {
    _viewerKey.currentState?.jumpToPage(targetPage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Jumped to page $targetPage'), duration: const Duration(seconds: 1)),
    );
  }

  // ... All existing methods for tap, long‑press, TTS, vocab, HUD remain exactly the same.
  // (I'll include them in the final commit but for brevity I’m referencing the last full version.)
  // They are unchanged.

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bandHeight = screenHeight * 0.35;
    final isTier = _tappedWord != null && _tierWords.contains(_tappedWord!.toLowerCase());
    final icon = _playbackState == PlaybackState.playing
        ? Icons.pause_circle_filled
        : Icons.play_circle_fill;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) _savePosition();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reader'),
          actions: [
            if (_ttsAvailable)
              IconButton(
                icon: Icon(icon, color: Colors.tealAccent),
                tooltip: _playbackState == PlaybackState.playing ? 'Stop reading' : 'Read All',
                onPressed: _toggleContinuousTts,
              ),
            IconButton(
              icon: Icon(_autoLinkOn ? Icons.link : Icons.link_off, color: _autoLinkOn ? Colors.blueAccent : null),
              tooltip: 'Auto‑Link',
              onPressed: _toggleAutoLink,
            ),
            IconButton(
              icon: Icon(_rulerOn ? Icons.remove_red_eye : Icons.remove_red_eye_outlined),
              tooltip: 'Reading Ruler',
              onPressed: () => setState(() => _rulerOn = !_rulerOn),
            ),
            IconButton(
              icon: Icon(_focusModeOn ? Icons.center_focus_strong : Icons.center_focus_weak),
              tooltip: 'Focus Mode',
              onPressed: () => setState(() => _focusModeOn = !_focusModeOn),
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'Document Stats',
              onPressed: () => Navigator.pushNamed(context, '/docstats', arguments: {'pdfPath': widget.pdfPath}),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => _dismissHUD(),
          child: Stack(
            children: [
              CustomPdfViewer(
                key: _viewerKey,
                filePath: widget.pdfPath,
                onWordTap: _onWordTap,
                onNoText: _onNoText,
                onWordMapReady: _onWordMapReady,
                onLongPress: _onLongPress,
                onPageChanged: _onPageChanged,
                linkTargets: _autoLinkOn ? _linkMap : null,
                onAutoLinkTap: _autoLinkOn ? _onAutoLinkTap : null,
              ),
              if (_tierRects.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: TierOverlayPainter(tierRects: _tierRects)),
                  ),
                ),
              if (_linkRects.isNotEmpty && _autoLinkOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: AutoLinkPainter(linkRects: _linkRects)),
                  ),
                ),
              // … existing overlays (loading, focus, ruler, ghost, hud) unchanged …
            ],
          ),
        ),
      ),
    );
  }

  // … all the remaining methods (onWordTap, _onLongPress, _showError, _saveToVocab, etc.) are identical to previous version.
  // They will be included in the full file commit.

import 'package:flutter/material.dart';
import '../core_bridge.dart';
import '../widgets/custom_pdf_viewer.dart';
import '../widgets/tier_overlay_painter.dart';
import '../services/vocab_bank.dart';
import '../services/pdf_text_service.dart';
import '../services/tts_service.dart';
import '../services/tier_highlighter.dart';
import '../services/reading_position.dart';
import 'dart:convert';
import 'dart:math';

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  final int? initialPage;
  const ReaderScreen({super.key, required this.pdfPath, this.initialPage});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // … existing state variables …
  String? _tappedWord;
  Map<String, dynamic>? _entry;
  Offset? _hudPosition;
  final CoreBridge _bridge = CoreBridge();
  bool _wordMapLoading = true;
  DateTime _lastTapTime = DateTime(2000);
  bool _rulerOn = false;
  bool _focusModeOn = false;
  String _sourceDocName = '';
  String? _ghostWord;
  String? _ghostDefinition;
  Offset? _ghostPosition;
  Set<String> _tierWords = {};
  final TtsService _tts = TtsService();
  bool _ttsAvailable = false;
  bool _ttsActive = false;
  final GlobalKey<CustomPdfViewerState> _viewerKey = GlobalKey<CustomPdfViewerState>();

  // Tier highlight state
  List<Rect> _tierRects = [];

  @override
  void initState() {
    super.initState();
    _sourceDocName = widget.pdfPath.split('/').last;
    _bridge.load();
    _tts.onError = (m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    _tts.init().then((ok) => setState(() => _ttsAvailable = ok));
    _restorePosition();
  }

  void _onWordMapReady() async {
    setState(() => _wordMapLoading = false);
    final viewerState = _viewerKey.currentState;
    if (viewerState != null && viewerState.isWordMapReady) {
      final tier = await TierHighlighter.getTierWords(viewerState.wordMap);
      if (mounted) {
        setState(() => _tierWords = tier);
        _updateTierRects();
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
  }

  // … existing tap, long‑press, TTS, HUD methods unchanged …
  // (keeping the full implementation from before)
  void _onWordTap(String word, Offset localPosition) { … }
  void _onLongPress(String word, Offset localPosition) { … }
  void _onNoText() { … }
  void _saveToVocab() { … }
  void _toggleReadAloud() { … }
  void _showError(String msg) { … }
  Offset _bestHudPosition(Offset near) { … }
  void _dismissHUD() { … }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bandHeight = screenHeight * 0.35;
    final isTier = _tappedWord != null && _tierWords.contains(_tappedWord!.toLowerCase());

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
                icon: Icon(_ttsActive ? Icons.volume_up : Icons.volume_down),
                tooltip: _ttsActive ? 'Stop reading' : 'Read aloud',
                onPressed: _toggleReadAloud,
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
              ),
              // Tier‑1 Highlight Overlay
              if (_tierRects.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: TierOverlayPainter(tierRects: _tierRects),
                    ),
                  ),
                ),
              if (_wordMapLoading)
                const Positioned(
                  top: 80, left: 0, right: 0,
                  child: Center(
                    child: Card(
                      color: Colors.black54,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Indexing words...', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
              if (_focusModeOn) ...[
                Positioned(top: 0, left: 0, right: 0, height: bandHeight,
                    child: Container(color: Colors.black54)),
                Positioned(bottom: 0, left: 0, right: 0, height: bandHeight,
                    child: Container(color: Colors.black54)),
              ],
              if (_rulerOn)
                Positioned(
                  left: 16, right: 16, top: screenHeight / 2,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.4),
                      boxShadow: [
                        BoxShadow(color: Colors.tealAccent.withOpacity(0.2), blurRadius: 6, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
              if (_ghostWord != null && _ghostPosition != null)
                Positioned(
                  left: _ghostPosition!.dx,
                  top: _ghostPosition!.dy,
                  child: Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '${_ghostWord!}: ${_ghostDefinition ?? "..."}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              if (_tappedWord != null && _entry != null && _hudPosition != null)
                Positioned(
                  left: _hudPosition!.dx,
                  top: _hudPosition!.dy,
                  child: _buildHUD(isTier),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUD(bool isTier) { … /* existing HUD code */ }
}

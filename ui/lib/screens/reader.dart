import 'package:flutter/material.dart';
import '../core_bridge.dart';
import '../widgets/custom_pdf_viewer.dart';
import '../services/vocab_bank.dart';
import 'dart:convert';
import 'dart:math';

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  const ReaderScreen({super.key, required this.pdfPath});

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
  String _sourceDocName = '';

  // Contextual Ghost state
  String? _ghostWord;
  String? _ghostDefinition;
  Offset? _ghostPosition;

  @override
  void initState() {
    super.initState();
    _sourceDocName = widget.pdfPath.split('/').last;
    _bridge.load();
  }

  void _onWordMapReady() => setState(() => _wordMapLoading = false);

  void _onWordTap(String word, Offset localPosition) {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 200) return;
    _lastTapTime = now;

    if (_bridge.state != EngineState.ready) {
      _showError('Engine not ready');
      return;
    }

    String jsonStr;
    try { jsonStr = _bridge.lookup(word); } catch (e) { _showError('Lookup failed'); return; }
    if (jsonStr == '[]') { _showError('No definition found'); return; }
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _tappedWord = word;
          _entry = parsed;
          _hudPosition = _bestHudPosition(localPosition);
          _ghostWord = null; // dismiss ghost
        });
      }
    } catch (e) { _showError('Parse error'); }
  }

  void _onLongPress(String word, Offset localPosition) {
    if (_bridge.state != EngineState.ready) return;
    String jsonStr;
    try { jsonStr = _bridge.lookup(word); } catch (_) { return; }
    if (jsonStr == '[]') return;
    try {
      final parsed = jsonDecode(jsonStr);
      String? def;
      if (parsed is Map<String, dynamic>) {
        final defs = (parsed['definitions'] as List?)?.cast<String>() ?? [];
        def = defs.isNotEmpty ? defs.first : null;
      }
      setState(() {
        _ghostWord = word;
        _ghostDefinition = def;
        _ghostPosition = Offset(localPosition.dx, localPosition.dy - 30);
        _tappedWord = null; // dismiss full HUD
      });
    } catch (_) {}
  }

  void _onNoText() => _showError('No text layer (scanned PDF?)');

  void _showError(String msg) {
    setState(() {
      _tappedWord = msg;
      _entry = {'word_type': '', 'definitions': [], 'synonyms': []};
      _hudPosition = const Offset(20, 100);
      _ghostWord = null;
    });
  }

  void _saveToVocab() {
    if (_entry == null || _tappedWord == null) return;
    final defs = (_entry!['definitions'] as List?)?.cast<String>() ?? [];
    final entry = VocabEntry(
      word: _tappedWord!,
      definition: defs.isNotEmpty ? defs.first : '',
      wordType: _entry!['word_type'] ?? '',
      synonyms: (_entry!['synonyms'] as List?)?.cast<String>() ?? [],
      sourceDocument: _sourceDocName,
      savedAt: DateTime.now(),
    );
    VocabBank.add(entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${_tappedWord}" saved to Vocabulary Bank')),
    );
  }

  Offset _bestHudPosition(Offset near) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    const cardW = 250.0, cardH = 160.0, pad = 12.0;
    double left = near.dx - cardW / 2;
    double top = near.dy - cardH - 40;
    if (left < pad) left = pad;
    if (left + cardW > w - pad) left = w - cardW - pad;
    if (top < pad) top = near.dy + 40;
    if (top + cardH > h - pad) top = h - cardH - pad;
    return Offset(left, max(pad, top));
  }

  void _dismissHUD() {
    setState(() {
      _tappedWord = null;
      _entry = null;
      _hudPosition = null;
      _ghostWord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bandHeight = screenHeight * 0.35;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reader'),
        actions: [
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
        ],
      ),
      body: GestureDetector(
        onTap: () => _dismissHUD(),
        child: Stack(
          children: [
            CustomPdfViewer(
              filePath: widget.pdfPath,
              onWordTap: _onWordTap,
              onNoText: _onNoText,
              onWordMapReady: _onWordMapReady,
              onLongPress: _onLongPress,
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
            // Contextual Ghost (long‑press mini‑HUD)
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
            // Full Ghost HUD
            if (_tappedWord != null && _entry != null && _hudPosition != null)
              Positioned(
                left: _hudPosition!.dx,
                top: _hudPosition!.dy,
                child: _buildHUD(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    final wordType = _entry!['word_type'] ?? '';
    final definitions = (_entry!['definitions'] as List?)?.cast<String>() ?? [];
    final synonyms = (_entry!['synonyms'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {},
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[900]?.withOpacity(0.92),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_tappedWord!,
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    if (wordType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(wordType, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add, color: Colors.tealAccent, size: 20),
                      onPressed: _saveToVocab,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (definitions.isNotEmpty)
                  ...definitions.take(3).map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $d', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      )),
                if (definitions.isEmpty)
                  const Text('No definition found.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                if (synonyms.isNotEmpty)
                  Wrap(
                    spacing: 6, runSpacing: 2,
                    children: synonyms.take(6).map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.teal[700],
                          labelStyle: const TextStyle(color: Colors.white),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

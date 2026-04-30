import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core_bridge.dart';
import 'dart:convert';

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

  PdfDocument? _document;
  PdfViewerController? _controller;
  final GlobalKey _viewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    if (!_bridge.isLoaded) {
      await _bridge.load();
    }
  }

  Future<void> _onViewerTap(Offset globalPosition) async {
    if (_document == null || _controller == null) return;

    // 1. Convert global tap to widget-local coordinates
    final RenderBox? box =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPosition = box.globalToLocal(globalPosition);

    // 2. Convert widget-local coordinates to PDF page coordinates
    final pageOffset = _controller!.toPageCoordinate(localPosition);
    if (pageOffset == null) return;

    // 3. Determine current page (nullable, default to 1)
    final pageNumber = _controller!.pageNumber ?? 1;
    if (pageNumber < 1 || pageNumber > _document!.pages.length) return;

    // 4. Load text layer for current page
    final page = _document!.pages[pageNumber - 1];
    final pageText = await page.loadText();
    if (pageText == null) return;

    // 5. Hit-test: find word whose bounding rect contains the page offset
    String? word;
    for (final w in pageText.words) {
      if (w.rect.contains(pageOffset)) {
        word = w.text;
        break;
      }
    }

    if (word != null && word.isNotEmpty) {
      _fetchDefinition(word, pageOffset);
    }
  }

  void _fetchDefinition(String word, Offset tapPos) {
    String jsonStr;
    try {
      jsonStr = _bridge.lookup(word);
    } catch (e) {
      _showError('Lookup failed');
      return;
    }

    if (jsonStr == '[]') {
      _showError('No definition found');
      return;
    }

    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _tappedWord = word;
          _entry = parsed;
          _hudPosition = _calculateHudPosition(tapPos);
        });
      }
    } catch (e) {
      _showError('Parse error');
    }
  }

  void _showError(String msg) {
    setState(() {
      _tappedWord = msg;
      _entry = {'word_type': '', 'definitions': [], 'synonyms': []};
      _hudPosition = const Offset(20, 80);
    });
  }

  Offset _calculateHudPosition(Offset tap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    const double hudWidth = 250;
    const double hudHeight = 150;

    double left = tap.dx - hudWidth / 2;
    double top = tap.dy - hudHeight - 40;

    if (left < 16) left = 16;
    if (left + hudWidth > screenWidth - 16) left = screenWidth - hudWidth - 16;
    if (top < 80) top = tap.dy + 40;
    if (top + hudHeight > screenHeight - 40) top = screenHeight - hudHeight - 40;

    return Offset(left, top);
  }

  void _dismissHUD() {
    setState(() {
      _tappedWord = null;
      _entry = null;
      _hudPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: GestureDetector(
        onTapUp: (details) => _onViewerTap(details.globalPosition),
        child: Stack(
          key: _viewerKey,
          children: [
            PdfViewer.file(
              widget.pdfPath,
              params: PdfViewerParams(
                onViewerReady: (document, controller) {
                  _document = document;
                  _controller = controller;
                },
              ),
            ),
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
                      child: Text(
                        _tappedWord!,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (wordType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          wordType,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Colors.white70, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (definitions.isNotEmpty)
                  ...definitions.take(3).map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $d',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      )),
                if (definitions.isEmpty)
                  const Text('No definition found.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                if (synonyms.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
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

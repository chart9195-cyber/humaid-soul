import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core_bridge.dart';
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

  // ----------- TAP → PDF COORDINATE MAPPING (transformation‑based) -----------

  Future<void> _onViewerTap(Offset globalPosition) async {
    if (_document == null || _controller == null) return;

    // 1. Local widget coordinates
    final RenderBox? box =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);

    // 2. Use the viewer's transformation to map local → PDF page coordinates
    final Matrix4 transform = _controller!.transformation;
    // The inverse may fail if the matrix is singular; guard it.
    Matrix4 inverse;
    try {
      inverse = Matrix4.inverted(transform);
    } catch (_) {
      return;
    }

    // Transform local offset into PDF coordinate space
    final Vector4 pdfPoint = inverse.transform(Vector4(local.dx, local.dy, 0, 1));
    final Offset pageOffset = Offset(pdfPoint.x, pdfPoint.y);

    // 3. Determine current page (use default 1 if null)
    final int pageNumber = _controller!.pageNumber ?? 1;
    if (pageNumber < 1 || pageNumber > _document!.pages.length) return;

    // 4. Load text layer for the page
    final page = _document!.pages[pageNumber - 1];
    final PdfPageText? pageText = await page.loadText();
    if (pageText == null) return;

    // 5. Hit‑test every word (safe, uses only the stable `words` list)
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

  // ----------- DEFINITION FETCH & HUD -----------

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
          _hudPosition = _bestHudPosition(tapPos);
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
      _hudPosition = const Offset(20, 100);
    });
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
    });
  }

  // ----------- BUILD -----------

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
                      child: Text(_tappedWord!,
                          style: const TextStyle(
                              color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    if (wordType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.teal[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(wordType,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
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
                        child: Text('• $d',
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                      )),
                if (definitions.isEmpty)
                  const Text('No definition found.',
                      style: TextStyle(color: Colors.white70)),
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

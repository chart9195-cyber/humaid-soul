import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import '../services/word_map_cache.dart';

// ── Top‑level extraction (runs in isolate) ──
class _WordMapResult {
  final List<List<WordEntry>> wordMap;
  final double pageWidth;
  final double pageHeight;
  const _WordMapResult(this.wordMap, this.pageWidth, this.pageHeight);
}

_WordMapResult _extractWordMap(String filePath) {
  final bytes = File(filePath).readAsBytesSync();
  final doc = sf_pdf.PdfDocument(inputBytes: bytes);
  final pageWidth = doc.pages[0].size.width;
  final pageHeight = doc.pages[0].size.height;

  final extractor = sf_pdf.PdfTextExtractor(doc);
  final lines = extractor.extractTextLines();
  final wordMap = <List<WordEntry>>[];
  for (final line in lines) {
    final pageIdx = line.pageIndex;
    while (wordMap.length <= pageIdx) {
      wordMap.add([]);
    }
    for (final word in line.wordCollection) {
      wordMap[pageIdx].add(WordEntry(
        text: word.text,
        bounds: word.bounds,
      ));
    }
  }
  doc.dispose();
  return _WordMapResult(wordMap, pageWidth, pageHeight);
}

// ── Viewer widget ──
class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;
  final void Function()? onWordMapReady;
  final void Function(String word, Offset localPosition)? onLongPress;
  final VoidCallback? onPageChanged;
  final void Function(int targetPage)? onAutoLinkTap;
  final Map<String, int>? linkTargets;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
    this.onWordMapReady,
    this.onLongPress,
    this.onPageChanged,
    this.onAutoLinkTap,
    this.linkTargets,
  });

  @override
  CustomPdfViewerState createState() => CustomPdfViewerState();
}

class CustomPdfViewerState extends State<CustomPdfViewer> {
  List<List<WordEntry>> _wordMap = [];
  bool _wordMapReady = false;
  final PdfViewerController _controller = PdfViewerController();
  double _pageWidth = 0;
  double _pageHeight = 0;
  Size _viewerSize = Size.zero;

  List<List<WordEntry>> get wordMap => _wordMap;
  bool get isWordMapReady => _wordMapReady;
  PdfViewerController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _buildWordMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) _viewerSize = box.size;
    });
  }

  Future<void> _buildWordMap() async {
    try {
      // Try cache first
      final cached = await WordMapCache.load(widget.filePath);
      if (cached != null) {
        _wordMap = cached.wordMap;
        _pageWidth = cached.pageWidth;
        _pageHeight = cached.pageHeight;
        _wordMapReady = true;
        widget.onWordMapReady?.call();
        return;
      }

      // Extract in background isolate
      final result = await compute(_extractWordMap, widget.filePath);
      _wordMap = result.wordMap;
      _pageWidth = result.pageWidth;
      _pageHeight = result.pageHeight;

      // Save cache (also in background)
      WordMapCache.save(
        pdfPath: widget.filePath,
        wordMap: _wordMap,
        pageWidth: _pageWidth,
        pageHeight: _pageHeight,
      );

      _wordMapReady = true;
      widget.onWordMapReady?.call();
    } catch (e) {
      debugPrint('Word map build failed: $e');
      _wordMapReady = true;
      widget.onWordMapReady?.call();
    }
  }

  // ── All existing methods unchanged ──
  // (the full file content will be committed with all methods)
}

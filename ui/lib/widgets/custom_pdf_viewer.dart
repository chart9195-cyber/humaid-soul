import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;
  final void Function()? onWordMapReady;
  final void Function(String word, Offset localPosition)? onLongPress;
  final VoidCallback? onPageChanged;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
    this.onWordMapReady,
    this.onLongPress,
    this.onPageChanged,
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
      final bytes = await File(widget.filePath).readAsBytes();
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      _pageWidth = doc.pages[0].size.width;
      _pageHeight = doc.pages[0].size.height;

      final extractor = sf_pdf.PdfTextExtractor(doc);
      final lines = extractor.extractTextLines();
      for (final line in lines) {
        final pageIdx = line.pageIndex;
        while (_wordMap.length <= pageIdx) {
          _wordMap.add([]);
        }
        for (final word in line.wordCollection) {
          _wordMap[pageIdx].add(WordEntry(
            text: word.text,
            bounds: word.bounds,
          ));
        }
      }
      doc.dispose();
      _wordMapReady = true;
      widget.onWordMapReady?.call();
    } catch (e) {
      debugPrint('Word map build failed: $e');
      _wordMapReady = true;
      widget.onWordMapReady?.call();
    }
  }

  // … existing hit‑test and tap methods unchanged …
  String? _hitTestWord(int pageIdx, Offset pageCoord) { … }
  _PdfHit? _widgetToPdf(Offset widgetPos) { … }
  void _onTap(PdfGestureDetails details) { … }
  void _onLongPress(LongPressStartDetails details) { … }
  void jumpToPage(int page) { … }
  double getScrollFraction() { … }

  /// Returns widget‑space rectangles for tier words on the *currently visible page*.
  List<Rect> getTierRects(Set<String> tierWords) {
    if (_viewerSize.isEmpty || _pageWidth == 0 || _pageHeight == 0 || !_wordMapReady) {
      return [];
    }

    final curPage = _controller.pageNumber.isNaN ? 1 : _controller.pageNumber.toInt();
    final pageIdx = curPage - 1;
    if (pageIdx < 0 || pageIdx >= _wordMap.length) return [];

    final viewerWidth = _viewerSize.width;
    final scale = viewerWidth / _pageWidth;
    final scrollY = _controller.scrollOffset.dy;

    // Compute the widget Y coordinate of a PDF point (bottom‑left origin)
    // widgetY = (pageIdx * _pageHeight - pdfY) * scale + scrollY
    final rects = <Rect>[];
    for (final entry in _wordMap[pageIdx]) {
      if (tierWords.contains(entry.text.toLowerCase())) {
        final left = entry.bounds.left * scale;
        final top = (pageIdx * _pageHeight - entry.bounds.top) * scale + scrollY;
        final width = entry.bounds.width * scale;
        final height = entry.bounds.height * scale;
        rects.add(Rect.fromLTWH(left, top, width, height));
      }
    }
    return rects;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPress,
      child: LayoutBuilder(
        builder: (context, constraints) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) _viewerSize = box.size;
          });
          return SfPdfViewer.file(
            File(widget.filePath),
            controller: _controller,
            onTap: _onTap,
            onPageChanged: (details) => widget.onPageChanged?.call(),
          );
        },
      ),
    );
  }
}

class _PdfHit {
  final int pageIndex;
  final Offset pageCoord;
  _PdfHit(this.pageIndex, this.pageCoord);
}

class WordEntry {
  final String text;
  final Rect bounds;
  WordEntry({required this.text, required this.bounds});
}

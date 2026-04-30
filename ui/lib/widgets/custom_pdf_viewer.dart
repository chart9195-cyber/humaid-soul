import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;
  final void Function()? onWordMapReady;
  final void Function(String word, Offset localPosition)? onLongPress;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
    this.onWordMapReady,
    this.onLongPress,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  List<List<WordEntry>> _wordMap = [];
  bool _wordMapReady = false;
  final PdfViewerController _controller = PdfViewerController();
  double _pageWidth = 0;
  double _pageHeight = 0;

  @override
  void initState() {
    super.initState();
    _buildWordMap();
  }

  Future<void> _buildWordMap() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      _pageWidth = doc.pages[0].mediaBox.width;
      _pageHeight = doc.pages[0].mediaBox.height;

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

  String? _hitTestWord(int pageIdx, Offset pageCoord) {
    if (pageIdx < 0 || pageIdx >= _wordMap.length) return null;
    for (final entry in _wordMap[pageIdx]) {
      if (entry.bounds.contains(pageCoord)) {
        final text = entry.text.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  // Convert a widget‑space position to PDF page index + coordinates
  _PdfHit? _widgetToPdf(Offset widgetPos) {
    if (_pageWidth == 0 || _pageHeight == 0) return null;
    final Matrix4 transform = _controller.transformation;
    Matrix4 inverse;
    try {
      inverse = Matrix4.inverted(transform);
    } catch (_) {
      return null;
    }
    final pdfVec = inverse.transform(Vector4(widgetPos.dx, widgetPos.dy, 0, 1));
    final pdfX = pdfVec.x;
    final pdfY = pdfVec.y;
    // determine page index by Y coordinate (each page is _pageHeight in PDF units)
    final pageIdx = (pdfY / _pageHeight).floor();
    if (pageIdx < 0 || pageIdx >= _wordMap.length) return null;
    final pageY = pdfY - pageIdx * _pageHeight;
    return _PdfHit(pageIdx, Offset(pdfX, pageY));
  }

  void _onTap(PdfGestureDetails details) {
    if (!_wordMapReady) return;
    final pageNumber = details.pageNumber;
    if (pageNumber == null || pageNumber < 1) return;
    final pageIdx = pageNumber - 1;
    final pageOffset = details.pagePosition;
    if (pageOffset == null) return;

    final word = _hitTestWord(pageIdx, pageOffset);
    if (word != null) {
      widget.onWordTap?.call(word, details.position);
    } else {
      widget.onNoText?.call();
    }
  }

  void _onLongPress(LongPressStartDetails details) {
    if (!_wordMapReady || widget.onLongPress == null) return;
    final hit = _widgetToPdf(details.localPosition);
    if (hit == null) return;
    final word = _hitTestWord(hit.pageIndex, hit.pageCoord);
    if (word != null) {
      widget.onLongPress!(word, details.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPress,
      child: SfPdfViewer.file(
        File(widget.filePath),
        controller: _controller,
        onTap: _onTap,
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

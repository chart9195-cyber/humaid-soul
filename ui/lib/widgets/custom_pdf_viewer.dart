import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function(String word, Offset localPosition)? onWordLongPress;
  final void Function()? onNoText;
  final void Function()? onWordMapReady;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onWordLongPress,
    this.onNoText,
    this.onWordMapReady,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  List<List<WordEntry>> _wordMap = [];
  bool _wordMapReady = false;
  Timer? _longPressTimer;
  Offset? _pointerDownPosition;
  PdfViewerController? _controller;

  @override
  void initState() {
    super.initState();
    _buildWordMap();
  }

  Future<void> _buildWordMap() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
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

  void _onViewerCreated(PdfViewerController controller) {
    _controller = controller;
  }

  void _handleTap(PdfGestureDetails details) {
    _extractWord(details.position, details.pagePosition, details.pageNumber,
        isLongPress: false);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pointerDownPosition != null) {
        _tryLongPress(_pointerDownPosition!);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
  }

  void _tryLongPress(Offset widgetPosition) {
    if (!_wordMapReady || _controller == null) return;

    // Convert widget coordinates to page coordinates using controller
    final pageCoord = _controller!.toPageCoordinate(widgetPosition);
    if (pageCoord == null) return;

    final pageNumber = _controller!.pageNumber ?? 1;
    _extractWord(widgetPosition, pageCoord, pageNumber, isLongPress: true);
  }

  void _extractWord(Offset widgetPosition, Offset pagePosition, int? pageNumber,
      {required bool isLongPress}) {
    if (!_wordMapReady) return;
    if (pageNumber == null || pageNumber < 1) return;

    final pageIdx = pageNumber - 1;
    if (pageIdx >= _wordMap.length) return;

    for (final entry in _wordMap[pageIdx]) {
      if (entry.bounds.contains(pagePosition)) {
        final word = entry.text.trim();
        if (word.isNotEmpty) {
          if (isLongPress) {
            widget.onWordLongPress?.call(word, widgetPosition);
          } else {
            widget.onWordTap?.call(word, widgetPosition);
          }
        }
        return;
      }
    }
    widget.onNoText?.call();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SfPdfViewer.file(
          File(widget.filePath),
          onTap: _handleTap,
          onPdfViewerCreated: _onViewerCreated,
        ),
        // Transparent overlay for long press detection
        Positioned.fill(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class WordEntry {
  final String text;
  final Rect bounds;
  WordEntry({required this.text, required this.bounds});
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;
  final VoidCallback? onWordMapReady;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
    this.onWordMapReady,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  List<List<WordEntry>> _wordMap = [];
  bool _wordMapReady = false;

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
      _wordMapReady = true; // allow interaction even if empty
      widget.onWordMapReady?.call();
    }
  }

  void _onTap(PdfGestureDetails details) {
    if (!_wordMapReady) return;

    final pageNumber = details.pageNumber;
    if (pageNumber == null || pageNumber < 1) return;

    final pageIdx = pageNumber - 1;
    if (pageIdx >= _wordMap.length) return;

    final pageOffset = details.pagePosition;
    if (pageOffset == null) return;

    for (final entry in _wordMap[pageIdx]) {
      if (entry.bounds.contains(pageOffset)) {
        final word = entry.text.trim();
        if (word.isNotEmpty) {
          final widgetPosition = details.position;
          widget.onWordTap?.call(word, widgetPosition);
        }
        return;
      }
    }
    widget.onNoText?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.file(
      File(widget.filePath),
      onTap: _onTap,
    );
  }
}

class WordEntry {
  final String text;
  final Rect bounds;
  WordEntry({required this.text, required this.bounds});
}

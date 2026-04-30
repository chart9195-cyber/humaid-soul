import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;
  final void Function(bool success)? onWordMapReady;

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
  bool _wordMapSuccess = false;

  @override
  void initState() {
    super.initState();
    _buildWordMap();
  }

  Future<void> _buildWordMap() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) throw Exception('PDF file not found.');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('PDF file is empty.');

      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      if (doc.pages.count == 0) throw Exception('PDF has no pages.');

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
      _wordMapSuccess = true;
    } catch (e) {
      debugPrint('Word map build failed: $e');
      _wordMapSuccess = false;
      _wordMap = []; // ensure empty
    }
    _wordMapReady = true;
    widget.onWordMapReady?.call(_wordMapSuccess);
  }

  void _onTap(PdfGestureDetails details) {
    if (!_wordMapReady || !_wordMapSuccess) return;

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

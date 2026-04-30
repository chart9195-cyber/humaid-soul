import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

/// Custom PDF viewer that pre‑computes a word map (word + bounds per page)
/// using syncfusion_flutter_pdf, then hit‑tests on tap.
class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  // wordMap[pageIndex 0‑based] = list of (word, bounds‑in‑PDF‑coords)
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

      // Group lines by page index
      for (final line in lines) {
        final pageIdx = line.pageIndex;
        // Expand list as needed
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
    } catch (e) {
      debugPrint('Word map build failed: $e');
      _wordMapReady = false;
    }
  }

  void _onTap(PdfGestureDetails details) {
    if (!_wordMapReady) {
      // Word map not ready yet → try fallback: tap gesture but no text extraction
      // still fire with empty word so UI can show "loading" state
      return;
    }

    final pageNumber = details.pageNumber;
    if (pageNumber == null || pageNumber < 1) return;

    // Syncfusion pages are 1‑based; our wordMap is 0‑based
    final pageIdx = pageNumber - 1;
    if (pageIdx >= _wordMap.length) return;

    final pageOffset = details.pagePosition;
    if (pageOffset == null) return;

    // Hit‑test words on this page
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

    // Tap position didn't hit any word (e.g., empty space, image)
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

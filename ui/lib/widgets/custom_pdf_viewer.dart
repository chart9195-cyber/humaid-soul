import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dart_pdf/dart_pdf.dart';

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  late PdfDocument _pdfDoc;
  List<ui.Image> _pageImages = [];
  List<List<WordLocation>> _pageWords = []; // words per page
  int _currentPage = 0;
  bool _loading = true;
  double _imageScale = 1.0;
  Offset _imageOffset = Offset.zero; // top-left of image in widget coords

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final file = File(widget.filePath);
    final bytes = await file.readAsBytes();
    _pdfDoc = PdfDocument.fromBytes(bytes);
    _buildWordMap();
    await _renderCurrentPage();
    setState(() => _loading = false);
  }

  void _buildWordMap() {
    _pageWords = List.generate(_pdfDoc.pages.length, (_) => []);
    for (int i = 0; i < _pdfDoc.pages.length; i++) {
      final page = _pdfDoc.pages[i];
      final text = page.extractText();
      if (text != null) {
        for (final segment in text.segments) {
          _pageWords[i].add(WordLocation(
            word: segment.text,
            rect: segment.boundingBox,
          ));
        }
      }
    }
  }

  Future<void> _renderCurrentPage() async {
    final page = _pdfDoc.pages[_currentPage];
    final pageRect = page.mediaBox;
    // Render at 2x device pixel ratio for clarity
    final viewScale = 2.0 * MediaQuery.of(context).devicePixelRatio;
    final width = (pageRect.width * viewScale).round();
    final height = (pageRect.height * viewScale).round();
    final image = await page.render(
      width: width,
      height: height,
      format: PdfPageImageFormat.png,
    );
    if (image != null) {
      final uiImage = await decodeImageFromList(image.bytes);
      if (!mounted) return;
      setState(() {
        _pageImages.add(uiImage);
      });
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_loading || _pageImages.isEmpty) return;
    final size = context.size;
    if (size == null) return;

    // Determine which page image is currently visible (simplified: only page 0, later scroll)
    final image = _pageImages[_currentPage];
    final pageWidth = _pdfDoc.pages[_currentPage].mediaBox.width;
    final pageHeight = _pdfDoc.pages[_currentPage].mediaBox.height;

    // Calculate image display rect (fit width)
    final displayWidth = size.width;
    final displayHeight = (pageHeight / pageWidth) * displayWidth;
    final offsetY = (size.height - displayHeight) / 2;
    final imageRect = Rect.fromLTWH(0, offsetY, displayWidth, displayHeight);

    // Convert tap position to PDF coordinates
    final tapLocal = details.localPosition;
    final pdfX = (tapLocal.dx - imageRect.left) / imageRect.width * pageWidth;
    final pdfY = (tapLocal.dy - imageRect.top) / imageRect.height * pageHeight;

    // Hit test words
    for (final word in _pageWords[_currentPage]) {
      final rect = word.rect;
      if (rect.contains(pdfX, pdfY)) {
        widget.onWordTap?.call(word.word, tapLocal);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pageImages.isEmpty) {
      return const Center(child: Text('No pages'));
    }
    final image = _pageImages[_currentPage];
    final page = _pdfDoc.pages[_currentPage];
    final aspect = page.mediaBox.height / page.mediaBox.width;

    return LayoutBuilder(builder: (context, constraints) {
      final displayWidth = constraints.maxWidth;
      final displayHeight = displayWidth * aspect;
      return GestureDetector(
        onTapUp: _onTapUp,
        child: Center(
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: RawImage(image: image, fit: BoxFit.contain),
          ),
        ),
      );
    });
  }
}

class WordLocation {
  final String word;
  final Rect rect; // in PDF coordinates (bottom-left origin, but we treat as top-left for simplicity)
  WordLocation({required this.word, required this.rect});
}

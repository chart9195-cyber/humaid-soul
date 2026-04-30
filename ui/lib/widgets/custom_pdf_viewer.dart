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
  int _pageCount = 0;
  double _pageWidth = 0, _pageHeight = 0;
  List<List<WordLocation>> _pageWords = [];
  final Map<int, ui.Image> _pageImages = {};
  final Map<int, Future<ui.Image>?> _renderFutures = {};
  final ScrollController _scrollController = ScrollController();
  double _screenWidth = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final file = File(widget.filePath);
    final bytes = await file.readAsBytes();
    _pdfDoc = PdfDocument.fromBytes(bytes);
    _pageCount = _pdfDoc.pages.length;
    final firstPage = _pdfDoc.pages[0];
    _pageWidth = firstPage.mediaBox.width;
    _pageHeight = firstPage.mediaBox.height;
    _buildWordMap();
    await _preRenderVisible(0);
    setState(() {});
  }

  void _buildWordMap() {
    _pageWords = List.generate(_pageCount, (_) => []);
    for (int i = 0; i < _pageCount; i++) {
      final page = _pdfDoc.pages[i];
      final text = page.extractText();
      if (text != null) {
        for (final seg in text.segments) {
          _pageWords[i].add(WordLocation(
            word: seg.text,
            rect: seg.boundingBox,
          ));
        }
      }
    }
  }

  Future<ui.Image> _renderPage(int pageIndex) async {
    final page = _pdfDoc.pages[pageIndex];
    final viewScale = 1.5 * MediaQuery.of(context).devicePixelRatio;
    final width = max(200, (_pageWidth * viewScale).round());
    final height = max(200, (_pageHeight * viewScale).round());
    final pngData = await page.render(
      width: width,
      height: height,
      format: PdfPageImageFormat.png,
    );
    if (pngData == null) throw Exception('Render failed');
    final image = await decodeImageFromList(pngData.bytes);
    return image;
  }

  Future<void> _preRenderVisible(int centerPage) async {
    // Render a small window around the visible page
    final start = max(0, centerPage - 2);
    final end = min(_pageCount, centerPage + 3);
    for (int i = start; i < end; i++) {
      if (!_pageImages.containsKey(i) && _renderFutures[i] == null) {
        final future = _renderPage(i);
        _renderFutures[i] = future;
        final image = await future;
        if (!mounted) return;
        _pageImages[i] = image;
        _renderFutures[i] = null;
      }
    }
    // Dispose images not in the window
    final keep = {start, end - 1, start + 1, end - 2, centerPage};
    _pageImages.keys
        .where((k) => !keep.contains(k))
        .toList()
        .forEach((k) {
      _pageImages[k]?.dispose();
      _pageImages.remove(k);
    });
    setState(() {});
  }

  void _onTapUp(TapUpDetails details) {
    if (_screenWidth == 0) return;
    final localPos = details.localPosition;
    final pageIndex = (localPos.dy / (_screenWidth * (_pageHeight / _pageWidth))).floor();
    if (pageIndex < 0 || pageIndex >= _pageCount) return;

    final pageImage = _pageImages[pageIndex];
    if (pageImage == null) return;

    final imageHeight = _screenWidth * (_pageHeight / _pageWidth);
    final yInPage = localPos.dy - pageIndex * imageHeight;
    final xInPage = localPos.dx;

    // Convert to PDF coordinates (bottom‑left origin in PDF, but we treat as top‑left)
    final scaleX = _pageWidth / _screenWidth;
    final scaleY = _pageHeight / imageHeight;
    final pdfX = xInPage * scaleX;
    final pdfY = yInPage * scaleY;

    for (final word in _pageWords[pageIndex]) {
      if (word.rect.contains(pdfX, pdfY)) {
        widget.onWordTap?.call(word.word, details.localPosition);
        break;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pdfDoc.dispose();
    for (final img in _pageImages.values) {
      img.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, constraints) {
      _screenWidth = constraints.maxWidth;
      final imageHeight = _screenWidth * (_pageHeight / _pageWidth);
      final totalHeight = imageHeight * _pageCount;

      // Pre-render based on scroll
      _scrollController.addListener(() {
        final scrollOffset = _scrollController.offset;
        final centerPage = (scrollOffset / imageHeight).floor();
        _preRenderVisible(centerPage);
      });

      return GestureDetector(
        onTapUp: _onTapUp,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _pageCount,
          itemExtent: imageHeight,
          itemBuilder: (context, index) {
            final image = _pageImages[index];
            if (image != null) {
              return SizedBox(
                width: _screenWidth,
                height: imageHeight,
                child: RawImage(image: image, fit: BoxFit.cover),
              );
            } else {
              return Container(
                width: _screenWidth,
                height: imageHeight,
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator()),
              );
            }
          },
        ),
      );
    });
  }
}

class WordLocation {
  final String word;
  final Rect rect;
  WordLocation({required this.word, required this.rect});
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class CustomPdfViewer extends StatelessWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
  });

  void _onTap(PdfTapDetails details) {
    final text = details.text;
    if (text != null && text.isNotEmpty && onWordTap != null) {
      onWordTap!(text, details.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.file(
      File(filePath),
      onTap: _onTap,
    );
  }
}

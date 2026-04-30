import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class CustomPdfViewer extends StatelessWidget {
  final String filePath;
  final void Function(String word, Offset localPosition)? onWordTap;
  final void Function()? onNoText;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onWordTap,
    this.onNoText,
  });

  void _onTap(PdfTapDetails details) {
    final text = details.text;
    if (text == null || text.trim().isEmpty) {
      // PDF has no selectable text layer (likely scanned)
      onNoText?.call();
    } else {
      onWordTap?.call(text, details.localPosition);
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

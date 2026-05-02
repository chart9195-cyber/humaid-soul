import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class ThumbnailService {
  /// Returns the cached thumbnail path for a PDF, generating it if needed.
  static Future<String?> getThumbnail(String pdfPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/thumbnails');
    if (!await thumbDir.exists()) await thumbDir.create();

    final safeName = pdfPath.hashCode.toRadixString(36);
    final thumbPath = '${thumbDir.path}/$safeName.png';

    if (File(thumbPath).existsSync()) return thumbPath;

    // Generate thumbnail from first page
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      if (doc.pages.count == 0) return null;

      final page = doc.pages[0];
      final size = page.size;
      // Render at a small width
      const thumbWidth = 200;
      final scale = thumbWidth / size.width;
      final thumbHeight = (size.height * scale).round();

      final pageImage = await page.render(width: thumbWidth, height: thumbHeight);
      if (pageImage == null) return null;

      final image = await decodeImageFromList(pageImage.bytes);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await File(thumbPath).writeAsBytes(byteData.buffer.asUint8List());
      doc.dispose();
      return thumbPath;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // for Rect
import 'package:flutter/foundation.dart';
import '../widgets/custom_pdf_viewer.dart';

class WordMapCache {
  static const String _magic = 'HUMS';
  static const int _version = 1;

  static Future<void> save({
    required String pdfPath,
    required List<List<WordEntry>> wordMap,
    required double pageWidth,
    required double pageHeight,
  }) async {
    try {
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) return;
      final pdfModified = pdfFile.lastModifiedSync().millisecondsSinceEpoch;

      final raw = _serialize(wordMap, pageWidth, pageHeight, pdfModified);
      final compressed = gzip.encode(raw);

      final cachePath = _cachePath(pdfPath);
      await File(cachePath).writeAsBytes(compressed, flush: true);

      debugPrint('📦 Word‑Map cache saved: ${cachePath.split('/').last} '
          '(${raw.length}→${compressed.length} bytes)');
    } catch (e) {
      debugPrint('Word‑Map cache save failed (non‑fatal): $e');
    }
  }

  static Future<WordMapCacheResult?> load(String pdfPath) async {
    try {
      final cachePath = _cachePath(pdfPath);
      final cacheFile = File(cachePath);
      if (!cacheFile.existsSync()) return null;

      final compressed = await cacheFile.readAsBytes();
      final raw = Uint8List.fromList(gzip.decode(compressed));

      final result = _deserialize(raw);

      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) return null;
      final currentModified = pdfFile.lastModifiedSync().millisecondsSinceEpoch;
      if (currentModified != result.pdfModifiedMs) {
        debugPrint('📦 Cache stale (pdf modified); discarding');
        await cacheFile.delete();
        return null;
      }

      debugPrint('📦 Word‑Map cache loaded: ${cachePath.split('/').last} '
          '(${compressed.length}→${raw.length} bytes, '
          '${result.wordMap.fold<int>(0, (s, p) => s + p.length)} words)');
      return result;
    } catch (e) {
      debugPrint('Word‑Map cache load failed (non‑fatal): $e');
      try { await File(_cachePath(pdfPath)).delete(); } catch (_) {}
      return null;
    }
  }

  static Future<void> invalidate(String pdfPath) async {
    try {
      final f = File(_cachePath(pdfPath));
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  static String _cachePath(String pdfPath) => '$pdfPath.humaid_cache';

  static Uint8List _serialize(
    List<List<WordEntry>> wordMap,
    double pageWidth,
    double pageHeight,
    int pdfModifiedMs,
  ) {
    int totalSize = _headerSize() + _pagesHeaderSize(wordMap) + _wordsDataSize(wordMap);
    final buf = ByteData(totalSize);
    int offset = 0;

    for (int i = 0; i < _magic.length; i++) {
      buf.setUint8(offset++, _magic.codeUnitAt(i));
    }
    buf.setUint16(offset, _version, Endian.little); offset += 2;
    buf.setUint64(offset, pdfModifiedMs, Endian.little); offset += 8;
    offset += 4; // reserved
    buf.setUint32(offset, wordMap.length, Endian.little); offset += 4;
    buf.setFloat32(offset, pageWidth, Endian.little); offset += 4;
    buf.setFloat32(offset, pageHeight, Endian.little); offset += 4;

    for (final page in wordMap) {
      buf.setUint32(offset, page.length, Endian.little); offset += 4;
      for (final entry in page) {
        final textBytes = utf8.encode(entry.text);
        buf.setUint16(offset, textBytes.length, Endian.little); offset += 2;
        for (int i = 0; i < textBytes.length; i++) {
          buf.setUint8(offset++, textBytes[i]);
        }
        buf.setFloat32(offset, entry.bounds.left, Endian.little); offset += 4;
        buf.setFloat32(offset, entry.bounds.top, Endian.little); offset += 4;
        buf.setFloat32(offset, entry.bounds.right, Endian.little); offset += 4;
        buf.setFloat32(offset, entry.bounds.bottom, Endian.little); offset += 4;
      }
    }

    return buf.buffer.asUint8List();
  }

  static WordMapCacheResult _deserialize(Uint8List raw) {
    final buf = ByteData.sublistView(raw);
    int offset = 0;

    for (int i = 0; i < _magic.length; i++) {
      if (buf.getUint8(offset++) != _magic.codeUnitAt(i)) {
        throw FormatException('Invalid cache magic');
      }
    }
    final version = buf.getUint16(offset, Endian.little); offset += 2;
    if (version != _version) throw FormatException('Unknown cache version $version');
    final pdfModifiedMs = buf.getUint64(offset, Endian.little); offset += 8;
    offset += 4; // reserved
    final pageCount = buf.getUint32(offset, Endian.little); offset += 4;
    final pageWidth = buf.getFloat32(offset, Endian.little); offset += 4;
    final pageHeight = buf.getFloat32(offset, Endian.little); offset += 4;

    final wordMap = <List<WordEntry>>[];
    for (int p = 0; p < pageCount; p++) {
      final wordCount = buf.getUint32(offset, Endian.little); offset += 4;
      final page = <WordEntry>[];
      for (int w = 0; w < wordCount; w++) {
        final textLen = buf.getUint16(offset, Endian.little); offset += 2;
        final text = utf8.decode(raw.sublist(offset, offset + textLen));
        offset += textLen;
        final left   = buf.getFloat32(offset, Endian.little); offset += 4;
        final top    = buf.getFloat32(offset, Endian.little); offset += 4;
        final right  = buf.getFloat32(offset, Endian.little); offset += 4;
        final bottom = buf.getFloat32(offset, Endian.little); offset += 4;
        page.add(WordEntry(
          text: text,
          bounds: Rect.fromLTRB(left, top, right, bottom),
        ));
      }
      wordMap.add(page);
    }

    return WordMapCacheResult(
      wordMap: wordMap,
      pdfModifiedMs: pdfModifiedMs,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
  }

  static int _headerSize() => 4 + 2 + 8 + 4 + 4 + 4 + 4; // 30 bytes
  static int _pagesHeaderSize(List<List<WordEntry>> wordMap) => wordMap.length * 4;
  static int _wordsDataSize(List<List<WordEntry>> wordMap) {
    int s = 0;
    for (final page in wordMap) {
      for (final entry in page) {
        s += 2 + utf8.encode(entry.text).length + 16;
      }
    }
    return s;
  }
}

class WordMapCacheResult {
  final List<List<WordEntry>> wordMap;
  final int pdfModifiedMs;
  final double pageWidth;
  final double pageHeight;
  const WordMapCacheResult({
    required this.wordMap,
    required this.pdfModifiedMs,
    required this.pageWidth,
    required this.pageHeight,
  });
}

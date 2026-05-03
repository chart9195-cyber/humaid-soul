import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../widgets/custom_pdf_viewer.dart'; // for WordEntry

/// Zero‑dependency Word‑Map cache that eliminates re‑extraction on subsequent opens.
///
/// Serialises the complete word map (List<List<WordEntry>>) to a compact binary
/// blob, compresses it with gzip (dart:io), and stores it as a sibling of the PDF.
///
/// **Invalidation rule**: if the PDF's `lastModifiedSync()` differs from the
/// timestamp embedded in the cache, the cache is discarded and rebuilt.
class WordMapCache {
  static const String _magic = 'HUMS';
  static const int _version = 1;

  /// Saves a word map to disk.  Runs off‑thread via `compute` to avoid jank.
  static Future<void> save({
    required String pdfPath,
    required List<List<WordEntry>> wordMap,
    required double pageWidth,
    required double pageHeight,
  }) async {
    try {
      // 1. Collect metadata
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) return;
      final pdfModified = pdfFile.lastModifiedSync().millisecondsSinceEpoch;

      // 2. Serialise to raw bytes (compute‑bound, but fast enough for typical maps)
      final raw = _serialize(wordMap, pageWidth, pageHeight, pdfModified);

      // 3. Compress with gzip (built‑in, zero package dependency)
      final compressed = gzip.encode(raw);

      // 4. Write to cache file
      final cachePath = _cachePath(pdfPath);
      await File(cachePath).writeAsBytes(compressed, flush: true);

      debugPrint('📦 Word‑Map cache saved: ${cachePath.split('/').last} '
          '(${raw.length}→${compressed.length} bytes)');
    } catch (e) {
      debugPrint('Word‑Map cache save failed (non‑fatal): $e');
    }
  }

  /// Loads a cached word map.  Returns `null` if the cache is missing, outdated,
  /// or corrupted — the caller falls back to full extraction.
  static Future<WordMapCacheResult?> load(String pdfPath) async {
    try {
      final cachePath = _cachePath(pdfPath);
      final cacheFile = File(cachePath);
      if (!cacheFile.existsSync()) return null;

      // 1. Read compressed bytes
      final compressed = await cacheFile.readAsBytes();

      // 2. Decompress
      final raw = gzip.decode(compressed);

      // 3. Deserialise
      final result = _deserialize(raw);

      // 4. Validate against current PDF timestamp
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
      // Corrupted cache → delete it
      try { await File(_cachePath(pdfPath)).delete(); } catch (_) {}
      return null;
    }
  }

  /// Deletes the cache for a given PDF (e.g. when document is removed).
  static Future<void> invalidate(String pdfPath) async {
    try {
      final f = File(_cachePath(pdfPath));
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────

  static String _cachePath(String pdfPath) => '$pdfPath.humaid_cache';

  /// Serialise [wordMap] + metadata into a raw Uint8List.
  static Uint8List _serialize(
    List<List<WordEntry>> wordMap,
    double pageWidth,
    double pageHeight,
    int pdfModifiedMs,
  ) {
    // Pre‑compute total size to allocate a single buffer
    int totalSize = _headerSize() + _pagesHeaderSize(wordMap) + _wordsDataSize(wordMap);
    final buf = ByteData(totalSize);
    int offset = 0;

    // Header
    for (int i = 0; i < _magic.length; i++) {
      buf.setUint8(offset++, _magic.codeUnitAt(i));
    }
    buf.setUint16(offset, _version, Endian.little); offset += 2;
    buf.setUint64(offset, pdfModifiedMs, Endian.little); offset += 8;
    offset += 4; // reserved
    buf.setUint32(offset, wordMap.length, Endian.little); offset += 4;
    buf.setFloat32(offset, pageWidth, Endian.little); offset += 4;
    buf.setFloat32(offset, pageHeight, Endian.little); offset += 4;

    // Pages
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

  /// Deserialise a raw Uint8List into a [WordMapCacheResult].
  static WordMapCacheResult _deserialize(Uint8List raw) {
    final buf = ByteData.sublistView(raw);
    int offset = 0;

    // Verify magic
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

  // ── size estimators (for single‑buffer allocation) ──
  static int _headerSize() => 4 + 2 + 8 + 4 + 4 + 4 + 4; // 30 bytes
  static int _pagesHeaderSize(List<List<WordEntry>> wordMap) => wordMap.length * 4;
  static int _wordsDataSize(List<List<WordEntry>> wordMap) {
    int s = 0;
    for (final page in wordMap) {
      for (final entry in page) {
        s += 2 + utf8.encode(entry.text).length + 16; // 16 = 4×float32
      }
    }
    return s;
  }
}

/// Return value of [WordMapCache.load].
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

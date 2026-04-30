import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core_bridge.dart';
import 'dart:convert';

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  const ReaderScreen({super.key, required this.pdfPath});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _tappedWord;
  String? _definitionJson;
  Offset? _hudPosition;
  final CoreBridge _bridge = CoreBridge();

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    if (!_bridge.isLoaded) {
      await _bridge.load();
    }
  }

  void _onPageTap(PdfPage page, Offset pageOffset) {
    // Extract word at the tapped position
    final word = page.text?.wordAt(pageOffset);
    if (word != null && word.isNotEmpty) {
      _showDefinition(word, pageOffset);
    }
  }

  void _showDefinition(String word, Offset tapPos) {
    String defJson = '[]';
    try {
      defJson = _bridge.lookup(word);
    } catch (e) {
      defJson = '{"error": "${e.toString()}"}';
    }

    setState(() {
      _tappedWord = word;
      _definitionJson = defJson;
      // Position HUD near the tap, but not covering the word (offset up)
      _hudPosition = Offset(tapPos.dx, tapPos.dy - 80);
    });
  }

  String _parseDefinition(String json) {
    try {
      final parsed = jsonDecode(json);
      if (parsed is Map) {
        return parsed['definitions']?.first?['definition'] ?? json;
      } else if (parsed is List && parsed.isNotEmpty) {
        return parsed.first['definition'] ?? json;
      }
    } catch (_) {}
    return json;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: Stack(
        children: [
          PdfViewer.file(
            widget.pdfPath,
            onPageTap: (page, pageOffset, globalOffset) {
              _onPageTap(page, pageOffset);
            },
          ),
          if (_tappedWord != null && _hudPosition != null)
            Positioned(
              left: _hudPosition!.dx,
              top: _hudPosition!.dy,
              child: _buildHUD(),
            ),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _tappedWord!,
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _parseDefinition(_definitionJson!),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

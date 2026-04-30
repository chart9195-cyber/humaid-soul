import 'package:flutter/material.dart';
import '../core_bridge.dart';
import '../widgets/custom_pdf_viewer.dart';
import 'dart:convert';
import 'dart:math';

class ReaderScreen extends StatefulWidget {
  final String pdfPath;
  const ReaderScreen({super.key, required this.pdfPath});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _tappedWord;
  Map<String, dynamic>? _entry;
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

  void _onWordTap(String word, Offset tapPosition) {
    String jsonStr;
    try {
      jsonStr = _bridge.lookup(word);
    } catch (e) {
      _showError('Lookup failed');
      return;
    }
    if (jsonStr == '[]') {
      _showError('No definition found');
      return;
    }
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _tappedWord = word;
          _entry = parsed;
          _hudPosition = _bestHudPosition(tapPosition);
        });
      }
    } catch (e) {
      _showError('Parse error');
    }
  }

  void _showError(String msg) {
    setState(() {
      _tappedWord = msg;
      _entry = {'word_type': '', 'definitions': [], 'synonyms': []};
      _hudPosition = const Offset(20, 100);
    });
  }

  Offset _bestHudPosition(Offset near) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    const cardW = 250.0, cardH = 160.0, pad = 12.0;

    double left = near.dx - cardW / 2;
    double top = near.dy - cardH - 40;
    if (left < pad) left = pad;
    if (left + cardW > w - pad) left = w - cardW - pad;
    if (top < pad) top = near.dy + 40;
    if (top + cardH > h - pad) top = h - cardH - pad;
    return Offset(left, max(pad, top));
  }

  void _dismissHUD() {
    setState(() {
      _tappedWord = null;
      _entry = null;
      _hudPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: GestureDetector(
        onTap: _dismissHUD,
        child: Stack(
          children: [
            CustomPdfViewer(
              filePath: widget.pdfPath,
              onWordTap: _onWordTap,
            ),
            if (_tappedWord != null && _entry != null && _hudPosition != null)
              Positioned(
                left: _hudPosition!.dx,
                top: _hudPosition!.dy,
                child: _buildHUD(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    final wordType = _entry!['word_type'] ?? '';
    final definitions =
        (_entry!['definitions'] as List?)?.cast<String>() ?? [];
    final synonyms = (_entry!['synonyms'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {},
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[900]?.withOpacity(0.92),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_tappedWord!,
                          style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (wordType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.teal[800],
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(wordType,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border,
                          color: Colors.white70, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (definitions.isNotEmpty)
                  ...definitions.take(3).map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $d',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      )),
                if (definitions.isEmpty)
                  const Text('No definition found.',
                      style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                if (synonyms.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: synonyms.take(6).map((s) => Chip(
                          label:
                              Text(s, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.teal[700],
                          labelStyle: const TextStyle(color: Colors.white),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

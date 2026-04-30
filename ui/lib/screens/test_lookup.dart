import 'package:flutter/material.dart';
import 'dart:convert';
import '../core_bridge.dart';

class TestLookupScreen extends StatefulWidget {
  const TestLookupScreen({super.key});

  @override
  State<TestLookupScreen> createState() => _TestLookupScreenState();
}

class _TestLookupScreenState extends State<TestLookupScreen> {
  final TextEditingController _wordController = TextEditingController();
  String _result = '';
  bool _loading = false;

  Future<void> _ensureEngineReady() async {
    final bridge = CoreBridge();

    // Already ready
    if (bridge.state == EngineState.ready) return;

    // Currently loading – wait a moment, then re‑check
    if (bridge.state == EngineState.loading) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (bridge.state == EngineState.ready) return;
      // fall through to error
    }

    // Not loaded yet or error – try loading now
    await bridge.load();
    if (bridge.state != EngineState.ready) {
      throw Exception(bridge.errorMessage ?? 'Engine failed to load.');
    }
  }

  Future<void> _performLookup() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      await _ensureEngineReady();

      final bridge = CoreBridge();
      final json = bridge.lookup(word);

      if (json == '[]') {
        _result = 'No definition found.';
      } else {
        final parsed = jsonDecode(json);
        if (parsed is List && parsed.isEmpty) {
          _result = 'No definition found.';
        } else {
          _result = const JsonEncoder.withIndent('  ').convert(parsed);
        }
      }
    } catch (e) {
      _result = 'Error: $e';
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Dictionary Lookup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: 'Enter a word',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _performLookup,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Lookup'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result.isEmpty ? 'Result will appear here.' : _result,
                  style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

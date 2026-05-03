import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About HUMAID SOUL')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'HUMAID SOUL',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent),
          ),
          const SizedBox(height: 4),
          const Text('v1.0.0 — Intelligence without Friction.',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          const Text('Attributions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _attributionTile(
            'Princeton WordNet 3.1',
            'The core English dictionary is derived from Princeton University\'s WordNet, a freely available lexical database.',
          ),
          _attributionTile(
            'Syncfusion Flutter PDF',
            'PDF rendering and text extraction are powered by Syncfusion® Flutter libraries under community license.',
          ),
          _attributionTile(
            'Sherpa‑Onnx',
            'Neural voices use Sherpa‑Onnx, a production‑ready offline TTS engine by the k2‑fsa organization. Voice models are from the Piper project by Rhasspy.',
          ),
          _attributionTile(
            'Flutter & Open‑Source',
            'This app is built entirely with Flutter and relies on a rich ecosystem of open‑source Dart packages. See pub.dev for the full dependency list.',
          ),
          const SizedBox(height: 24),
          const Text(
            'HUMAID SOUL respects your privacy. All data stays on your device — no analytics, no tracking, no cloud.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _attributionTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class WelcomeDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  const WelcomeDialog({super.key, required this.onDismiss});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  bool _loadingSample = false;

  Future<void> _loadSample() async {
    setState(() => _loadingSample = true);

    // Load a small, embedded sample text as a PDF? We don't have one.
    // Instead, we'll just guide the user to import their own PDF.
    // The sample could be a free public-domain text bundled as an asset.
    // For now, simply close and let the user import.

    widget.onDismiss();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Welcome to HUMAID SOUL',
          style: TextStyle(color: Colors.tealAccent)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your offline, intelligent reading companion.'),
          SizedBox(height: 16),
          Text('To get started:'),
          SizedBox(height: 8),
          Text('1. Tap the + icon to import a PDF.'),
          Text('2. Open it and tap any word for an instant definition.'),
          Text('3. Save words you want to remember.'),
          SizedBox(height: 16),
          Text('Everything works 100% offline — no internet needed.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onDismiss();
            Navigator.pop(context);
          },
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

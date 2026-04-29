import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUMAID SOUL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: import PDF
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Your Library\nNo documents yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/test'),
        label: const Text('Test Engine'),
        icon: const Icon(Icons.search),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../vocab.dart';

class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});

  @override
  State<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends State<VocabScreen> {
  List<VocabEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VocabBank.load();
    setState(() {
      _entries = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Bank')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No saved words yet.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final entry = _entries[i];
                    return ListTile(
                      title: Text(entry.word,
                          style: const TextStyle(color: Colors.tealAccent)),
                      subtitle: Text(entry.definition,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(entry.savedAt.toString().substring(0, 10)),
                    );
                  },
                ),
    );
  }
}

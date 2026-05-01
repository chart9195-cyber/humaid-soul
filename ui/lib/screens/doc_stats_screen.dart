import 'package:flutter/material.dart';
import '../services/tfidf_service.dart';

class DocStatsScreen extends StatefulWidget {
  final String pdfPath;
  const DocStatsScreen({super.key, required this.pdfPath});

  @override
  State<DocStatsScreen> createState() => _DocStatsScreenState();
}

class _DocStatsScreenState extends State<DocStatsScreen> {
  Map<String, double> _scores = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    try {
      final scores = await TfidfService.computeTfidf(widget.pdfPath);
      setState(() {
        _scores = scores;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to compute stats: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final docName = widget.pdfPath.split('/').last;
    return Scaffold(
      appBar: AppBar(title: Text('Keywords: $docName')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _scores.isEmpty
                  ? const Center(child: Text('No words found.'))
                  : ListView.builder(
                      itemCount: _scores.length,
                      itemBuilder: (_, i) {
                        final word = _scores.keys.elementAt(i);
                        final score = _scores[word]!;
                        return ListTile(
                          title: Text(word, style: const TextStyle(color: Colors.tealAccent)),
                          trailing: Text(score.toStringAsFixed(4)),
                        );
                      },
                    ),
    );
  }
}

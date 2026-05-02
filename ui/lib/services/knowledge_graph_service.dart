import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';
import 'pdf_text_service.dart';
import 'tfidf_service.dart';
import 'auto_link_service.dart';
import '../core_bridge.dart';

class GraphNode {
  final String id;
  final String label;
  final int frequency;
  final bool isTier1;
  double x;
  double y;
  double vx = 0, vy = 0;
  List<String>? definitions;
  List<String>? synonyms;

  GraphNode({
    required this.id,
    required this.label,
    required this.frequency,
    this.isTier1 = false,
    this.x = 0,
    this.y = 0,
  });
}

class GraphEdge {
  final String sourceId;
  final String targetId;
  final double weight; // 0.0 - 1.0

  GraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.weight,
  });
}

class KnowledgeGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  KnowledgeGraph({required this.nodes, required this.edges});
}

class KnowledgeGraphService {
  /// Builds a knowledge graph for the given document.
  static Future<KnowledgeGraph> buildGraph(String pdfPath) async {
    // 1. Get TF‑IDF keywords (top 30)
    final tfidfScores = await TfidfService.computeTfidf(pdfPath);
    final topWords = tfidfScores.entries
        .take(30)
        .where((e) => e.key.length > 3)
        .toList();

    if (topWords.isEmpty) return KnowledgeGraph(nodes: [], edges: []);

    // 2. Get full text and word map for co‑occurrence
    final textService = PdfTextService(pdfPath);
    final pageTexts = await textService.getPageTexts();
    final fullText = pageTexts.join(' ');

    // Split into paragraphs (heuristic: split on double newline or 5+ spaces)
    final paragraphs = fullText.split(RegExp(r'\n\s*\n|\s{5,}'));
    final topWordSet = topWords.map((e) => e.key.toLowerCase()).toSet();

    // 3. Compute co‑occurrence within paragraphs
    final cooccurrence = <String, Map<String, int>>{};
    for (final word in topWordSet) {
      cooccurrence[word] = {};
    }

    for (final para in paragraphs) {
      final paraLower = para.toLowerCase();
      final present = topWordSet.where((w) => paraLower.contains(w)).toList();
      for (int i = 0; i < present.length; i++) {
        for (int j = i + 1; j < present.length; j++) {
          final a = present[i];
          final b = present[j];
          cooccurrence[a]![b] = (cooccurrence[a]![b] ?? 0) + 1;
          cooccurrence[b]![a] = (cooccurrence[b]![a] ?? 0) + 1;
        }
      }
    }

    // 4. Build nodes
    final nodes = topWords.map((entry) {
      return GraphNode(
        id: entry.key,
        label: entry.key,
        frequency: entry.value.round(),
        isTier1: false, // can be updated from VocabBank later
      );
    }).toList();

    // 5. Build edges where co‑occurrence > 0
    final edges = <GraphEdge>[];
    final maxCooc = cooccurrence.values
        .expand((map) => map.values)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();

    for (final entry in cooccurrence.entries) {
      for (final target in entry.value.entries) {
        if (entry.key.compareTo(target.key) < 0) {
          final weight = maxCooc > 0 ? target.value / maxCooc : 0.0;
          edges.add(GraphEdge(
            sourceId: entry.key,
            targetId: target.key,
            weight: weight,
          ));
        }
      }
    }

    return KnowledgeGraph(nodes: nodes, edges: edges);
  }
}

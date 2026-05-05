import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pdf_text_service.dart';
import 'tfidf_service.dart';
import '../core_bridge.dart';

// ── Graph data classes (immutable, can cross isolates) ──

class GraphNode {
  final String id;
  final String label;
  final int frequency;
  final bool isTier1;
  double x;
  double y;

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
  final double weight;
  GraphEdge({required this.sourceId, required this.targetId, required this.weight});
}

class KnowledgeGraph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  KnowledgeGraph({required this.nodes, required this.edges});
}

// ── Input / output for the layout isolate ──

class _LayoutInput {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  _LayoutInput(this.nodes, this.edges);
}

class _LayoutOutput {
  final List<GraphNode> nodes;
  _LayoutOutput(this.nodes);
}

// ── Force‑directed layout (runs in background isolate) ──

_LayoutOutput _runLayout(_LayoutInput input) {
  const iterations = 120;
  const double repulsion = 5000;
  const double attraction = 0.01;
  const double damping = 0.85;
  final nodes = input.nodes;
  final edges = input.edges;
  final rng = Random(42);

  // Initialize random positions
  for (final node in nodes) {
    node.x = rng.nextDouble() * 600 - 300;
    node.y = rng.nextDouble() * 600 - 300;
  }

  for (int iter = 0; iter < iterations; iter++) {
    // Repulsion
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final dist = sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
        final force = repulsion / (dist * dist);
        final fx = force * dx / dist;
        final fy = force * dy / dist;
        nodes[i].x += fx;
        nodes[i].y += fy;
        nodes[j].x -= fx;
        nodes[j].y -= fy;
      }
    }
    // Attraction along edges
    for (final edge in edges) {
      final src = nodes.firstWhere((n) => n.id == edge.sourceId);
      final tgt = nodes.firstWhere((n) => n.id == edge.targetId);
      final dx = tgt.x - src.x;
      final dy = tgt.y - src.y;
      final dist = sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
      final force = attraction * dist * edge.weight;
      final fx = force * dx / dist;
      final fy = force * dy / dist;
      src.x += fx;
      src.y += fy;
      tgt.x -= fx;
      tgt.y -= fy;
    }
    // Damping
    for (final node in nodes) {
      node.x *= damping;
      node.y *= damping;
    }
  }

  // Center
  double minX = double.infinity, maxX = double.negativeInfinity;
  double minY = double.infinity, maxY = double.negativeInfinity;
  for (final node in nodes) {
    if (node.x < minX) minX = node.x;
    if (node.x > maxX) maxX = node.x;
    if (node.y < minY) minY = node.y;
    if (node.y > maxY) maxY = node.y;
  }
  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;
  for (final node in nodes) {
    node.x -= centerX;
    node.y -= centerY;
  }

  return _LayoutOutput(nodes);
}

// ── Public API ──

class KnowledgeGraphService {
  /// Builds a knowledge graph for the given document.
  /// Graph construction is I/O bound (file reads) and runs on the main isolate,
  /// which is acceptable because the heavy CPU work (layout) is deferred.
  static Future<KnowledgeGraph> buildGraph(String pdfPath) async {
    // 1. Get TF‑IDF keywords (top 30)
    final tfidfScores = await TfidfService.computeTfidf(pdfPath);
    final topWords = tfidfScores.entries
        .take(30)
        .where((e) => e.key.length > 3)
        .toList();

    if (topWords.isEmpty) return KnowledgeGraph(nodes: [], edges: []);

    // 2. Get full text for co‑occurrence
    final textService = PdfTextService(pdfPath);
    final pageTexts = await textService.getPageTexts();
    final fullText = pageTexts.join(' ');

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
        isTier1: false,
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

  /// Runs the force‑directed layout on a background isolate.
  static Future<List<GraphNode>> layoutGraph(KnowledgeGraph graph) async {
    if (graph.nodes.isEmpty) return [];
    final input = _LayoutInput(graph.nodes, graph.edges);
    final output = await compute(_runLayout, input);
    return output.nodes;
  }
}

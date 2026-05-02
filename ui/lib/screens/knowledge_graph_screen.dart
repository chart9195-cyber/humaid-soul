import 'dart:math';
import 'package:flutter/material.dart';
import '../services/knowledge_graph_service.dart';
import '../core_bridge.dart';

class KnowledgeGraphScreen extends StatefulWidget {
  final String pdfPath;
  const KnowledgeGraphScreen({super.key, required this.pdfPath});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  KnowledgeGraph? _graph;
  bool _loading = true;
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  Future<void> _buildGraph() async {
    final graph = await KnowledgeGraphService.buildGraph(widget.pdfPath);
    // Initialize random positions
    final rng = Random(42);
    for (final node in graph.nodes) {
      node.x = rng.nextDouble() * 400;
      node.y = rng.nextDouble() * 400;
    }
    setState(() {
      _graph = graph;
      _loading = false;
    });
    _simulateLayout();
  }

  void _simulateLayout() {
    if (_graph == null) return;
    const iterations = 100;
    const double repulsion = 5000;
    const double attraction = 0.01;
    const double damping = 0.9;

    final nodes = _graph!.nodes;
    final edges = _graph!.edges;

    for (int iter = 0; iter < iterations; iter++) {
      // Repulsion between all node pairs
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final dx = nodes[i].x - nodes[j].x;
          final dy = nodes[i].y - nodes[j].y;
          final dist = sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
          final force = repulsion / (dist * dist);
          final fx = force * dx / dist;
          final fy = force * dy / dist;
          nodes[i].vx += fx;
          nodes[i].vy += fy;
          nodes[j].vx -= fx;
          nodes[j].vy -= fy;
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
        src.vx += fx;
        src.vy += fy;
        tgt.vx -= fx;
        tgt.vy -= fy;
      }
      // Apply velocity
      for (final node in nodes) {
        node.x += node.vx;
        node.y += node.vy;
        node.vx *= damping;
        node.vy *= damping;
      }
    }

    // Center the graph
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

    setState(() {}); // repaint
  }

  void _onTapNode(String nodeId) async {
    setState(() => _selectedNodeId = nodeId);
    // Look up definitions for the tapped word
    final bridge = CoreBridge();
    final jsonStr = bridge.lookup(nodeId);
    // The HUD will show the definition
    // For now, we'll store it in the selected node? We'll handle with a bottom sheet.
    if (jsonStr != '[]') {
      showModalBottomSheet(
        context: context,
        builder: (_) => _buildDefinitionSheet(nodeId, jsonStr),
      );
    }
  }

  Widget _buildDefinitionSheet(String word, String jsonStr) {
    Map<String, dynamic>? entry;
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is Map<String, dynamic>) entry = parsed;
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word, style: const TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          if (entry != null) ...[
            const SizedBox(height: 8),
            Text(entry['word_type'] ?? '', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            ...((entry['definitions'] as List?)?.cast<String>() ?? []).take(3).map((d) => Text('• $d')),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Graph')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _graph == null || _graph!.nodes.isEmpty
              ? const Center(child: Text('Not enough data to build a graph.'))
              : InteractiveViewer(
                  child: SizedBox(
                    width: 800,
                    height: 800,
                    child: CustomPaint(
                      painter: _GraphPainter(
                        nodes: _graph!.nodes,
                        edges: _graph!.edges,
                        selectedNodeId: _selectedNodeId,
                      ),
                      child: Stack(
                        children: _graph!.nodes.map((node) {
                          return Positioned(
                            left: node.x + 400 - 25,
                            top: node.y + 400 - 25,
                            child: GestureDetector(
                              onTap: () => _onTapNode(node.id),
                              child: Container(
                                width: 50,
                                height: 50,
                                alignment: Alignment.center,
                                child: Text(
                                  node.label,
                                  style: const TextStyle(fontSize: 9, color: Colors.white),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedNodeId;

  _GraphPainter({required this.nodes, required this.edges, this.selectedNodeId});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);

    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    for (final edge in edges) {
      final src = nodes.firstWhere((n) => n.id == edge.sourceId);
      final tgt = nodes.firstWhere((n) => n.id == edge.targetId);
      canvas.drawLine(
        Offset(src.x, src.y) + origin,
        Offset(tgt.x, tgt.y) + origin,
        edgePaint..strokeWidth = 0.5 + edge.weight * 3,
      );
    }

    // Draw nodes
    for (final node in nodes) {
      final center = Offset(node.x, node.y) + origin;
      final isSelected = node.id == selectedNodeId;
      final radius = 10.0 + node.frequency * 2;
      final color = isSelected
          ? Colors.tealAccent
          : node.isTier1
              ? Colors.amber
              : Colors.teal;
      canvas.drawCircle(
        center,
        radius.clamp(12.0, 40.0),
        Paint()..color = color.withOpacity(0.8),
      );
      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: 60);
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) => true;
}

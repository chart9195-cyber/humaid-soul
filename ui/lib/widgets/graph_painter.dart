import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/knowledge_graph_service.dart';

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Offset cameraOffset;
  final double cameraScale;
  final GraphNode? hoveredNode;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.cameraOffset,
    required this.cameraScale,
    this.hoveredNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2 + cameraOffset.dx, size.height / 2 + cameraOffset.dy);
    canvas.scale(cameraScale);

    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5 / cameraScale;
    for (final edge in edges) {
      canvas.drawLine(
        Offset(edge.source.x, edge.source.y),
        Offset(edge.target.x, edge.target.y),
        edgePaint,
      );
    }

    // Draw nodes
    for (final node in nodes) {
      final isHovered = hoveredNode == node;
      final radius = (12 + (isHovered ? 6 : 0)) / cameraScale;

      // Glow
      final glowPaint = Paint()
        ..color = node.color.withOpacity(isHovered ? 0.6 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(node.x, node.y), radius + 4, glowPaint);

      // Circle
      final circlePaint = Paint()..color = node.color;
      canvas.drawCircle(Offset(node.x, node.y), radius, circlePaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.word,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 / cameraScale,
            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(node.x - textPainter.width / 2, node.y + radius + 4),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}

/// Spring‑embedder force simulation (Fruchterman–Reingold style).
class GraphSimulation {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  double damping = 0.95;
  double repulsion = 5000;
  double attraction = 0.01;
  double maxSpeed = 50;

  GraphSimulation({required this.nodes, required this.edges});

  void step() {
    // Repulsion between all node pairs
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final dist = max(1.0, sqrt(dx * dx + dy * dy));
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
      final dx = edge.target.x - edge.source.x;
      final dy = edge.target.y - edge.source.y;
      final dist = max(1.0, sqrt(dx * dx + dy * dy));
      final force = attraction * edge.strength * dist;
      final fx = force * dx / dist;
      final fy = force * dy / dist;
      edge.source.vx += fx;
      edge.source.vy += fy;
      edge.target.vx -= fx;
      edge.target.vy -= fy;
    }

    // Central gravity
    for (final node in nodes) {
      final dist = max(1.0, sqrt(node.x * node.x + node.y * node.y));
      node.vx -= 0.001 * node.x;
      node.vy -= 0.001 * node.y;
    }

    // Apply velocities
    for (final node in nodes) {
      final speed = sqrt(node.vx * node.vx + node.vy * node.vy);
      if (speed > maxSpeed) {
        node.vx = node.vx / speed * maxSpeed;
        node.vy = node.vy / speed * maxSpeed;
      }
      node.x += node.vx;
      node.y += node.vy;
      node.vx *= damping;
      node.vy *= damping;
    }
  }
}

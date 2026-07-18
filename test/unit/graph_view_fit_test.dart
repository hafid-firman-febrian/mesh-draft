import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/features/graph/presentation/widgets/graph_view.dart';

void main() {
  const viewport = Size(400, 800);

  test('seluruh bbox graf yang tersebar jauh dipetakan ke dalam viewport', () {
    // Kasus bug: node tersebar melewati kWorldSize, jauh dari sudut (0,0).
    const minX = 100.0;
    const minY = 300.0;
    const maxX = 5900.0;
    const maxY = 5400.0;

    final transform = fitToViewportTransform(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      viewport: viewport,
    );

    final corners = [
      const Offset(minX, minY),
      const Offset(maxX, minY),
      const Offset(minX, maxY),
      const Offset(maxX, maxY),
    ];
    for (final corner in corners) {
      final mapped = MatrixUtils.transformPoint(transform, corner);
      expect(mapped.dx, inInclusiveRange(0, viewport.width));
      expect(mapped.dy, inInclusiveRange(0, viewport.height));
    }
  });

  test('pusat bbox graf jatuh di pusat viewport', () {
    const minX = 1000.0;
    const minY = 2000.0;
    const maxX = 4000.0;
    const maxY = 3000.0;

    final transform = fitToViewportTransform(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      viewport: viewport,
    );

    final center = MatrixUtils.transformPoint(
      transform,
      const Offset((minX + maxX) / 2, (minY + maxY) / 2),
    );
    expect(center.dx, closeTo(viewport.width / 2, 0.001));
    expect(center.dy, closeTo(viewport.height / 2, 0.001));
  });
}

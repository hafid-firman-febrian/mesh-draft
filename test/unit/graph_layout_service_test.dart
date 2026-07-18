import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/features/graph/application/services/graph_layout_service.dart';

GraphNodeInput _free(String id) => (id: id, x: null, y: null);

void main() {
  test('graf tersimulasi konvergen: suhu mencapai nol dan beku', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('c')],
      edgeInputs: [(sourceId: 'a', targetId: 'b')],
    );

    expect(service.isConverged, isFalse);
    for (var i = 0; i < 600; i++) {
      service.step();
    }
    expect(service.isConverged, isTrue);
    expect(service.temperature, 0);
  });

  test('node dengan posisi tersimpan di-pin: tidak digerakkan simulasi', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [
        (id: 'pinned', x: 1000.0, y: 2000.0),
        _free('free1'),
        _free('free2'),
      ],
      edgeInputs: [
        (sourceId: 'pinned', targetId: 'free1'),
        (sourceId: 'pinned', targetId: 'free2'),
      ],
    );

    final pinned = service.nodes.firstWhere((n) => n.id == 'pinned');
    expect(pinned.pinned, isTrue);

    for (var i = 0; i < 600; i++) {
      service.step();
    }
    expect(pinned.position, const Offset(1000, 2000));
  });

  test('node bebas benar-benar digerakkan simulasi', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('c')],
      edgeInputs: [(sourceId: 'a', targetId: 'b')],
    );

    final before = {for (final n in service.nodes) n.id: n.position};
    for (var i = 0; i < 60; i++) {
      service.step();
    }
    final moved = service.nodes.any((n) => n.position != before[n.id]);
    expect(moved, isTrue);
  });

  test('posisi tetap finite setelah konvergen (20 node)', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [for (var i = 0; i < 20; i++) _free('$i')],
      edgeInputs: [
        for (var i = 1; i < 20; i++) (sourceId: '$i', targetId: '${i - 1}'),
      ],
    );

    for (var i = 0; i < 600; i++) {
      service.step();
    }
    for (final node in service.nodes) {
      expect(node.position.dx.isFinite, isTrue);
      expect(node.position.dy.isFinite, isTrue);
    }
  });

  test('nodeAt menemukan node dalam radius, null di luar', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [(id: 'a', x: 500.0, y: 500.0)],
      edgeInputs: [],
    );
    final a = service.nodes.single;

    expect(service.nodeAt(const Offset(500, 500)), same(a));
    expect(service.nodeAt(const Offset(505, 500)), same(a));
    expect(service.nodeAt(const Offset(900, 900)), isNull);
  });

  test('beginDrag membekukan node dan membangunkan simulasi yang sudah beku',
      () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b')],
      edgeInputs: [(sourceId: 'a', targetId: 'b')],
    );
    for (var i = 0; i < 600; i++) {
      service.step();
    }
    expect(service.isConverged, isTrue);

    final a = service.nodes.firstWhere((n) => n.id == 'a');
    service.beginDrag(a);

    expect(a.pinned, isTrue);
    expect(a.velocity, Offset.zero);
    expect(service.isConverged, isFalse);
  });

  test('dragTo menempatkan node persis di posisi jari dan menahannya di sana',
      () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('c')],
      edgeInputs: [
        (sourceId: 'a', targetId: 'b'),
        (sourceId: 'a', targetId: 'c'),
      ],
    );

    final a = service.nodes.firstWhere((n) => n.id == 'a');
    service.beginDrag(a);
    service.dragTo(a, const Offset(1234, 5678));

    for (var i = 0; i < 300; i++) {
      service.step();
    }
    expect(a.position, const Offset(1234, 5678));
  });

  test('mode drag: node bebas bergerak tanpa momentum (anti-getar)', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('c')],
      edgeInputs: [
        (sourceId: 'a', targetId: 'b'),
        (sourceId: 'a', targetId: 'c'),
      ],
    );

    final a = service.nodes.firstWhere((n) => n.id == 'a');
    service.beginDrag(a);
    // Drag kontinu: tiap frame node bergeser lalu step().
    for (var i = 0; i < 60; i++) {
      service.dragTo(a, a.position + const Offset(5, 0));
      service.step();
    }

    // Tanpa momentum, velocity tak pernah menumpuk → tak ada overshoot/osilasi
    // yang bikin getar (baik node yang di-drag maupun tetangganya).
    for (final node in service.nodes) {
      expect(node.velocity, Offset.zero);
    }
  });

  test('drag hanya menggerakkan node terpengaruh — node jauh tak terhubung diam',
      () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('far'), _free('farBuddy')],
      edgeInputs: [
        (sourceId: 'a', targetId: 'b'),
        (sourceId: 'far', targetId: 'farBuddy'),
      ],
    );
    final a = service.nodes.firstWhere((n) => n.id == 'a');
    final b = service.nodes.firstWhere((n) => n.id == 'b');
    final far = service.nodes.firstWhere((n) => n.id == 'far');
    final farBuddy = service.nodes.firstWhere((n) => n.id == 'farBuddy');

    // a-b dekat origin; far-farBuddy jauh dan pada jarak tak seimbang, jadi
    // 'far' punya sisa gaya sendiri (uji bahwa gate membekukannya, bukan sekadar
    // gaya nol).
    a.position = const Offset(0, 0);
    b.position = const Offset(100, 0);
    far.position = const Offset(5000, 5000);
    farBuddy.position = const Offset(5000, 5100);

    service.beginDrag(a);
    final farBefore = far.position;
    for (var i = 0; i < 30; i++) {
      service.dragTo(a, const Offset(20, 0));
      service.step();
    }

    expect(far.position, farBefore); // jauh & tak terhubung ke 'a' → beku
    expect(b.position, isNot(const Offset(100, 0))); // tetangga 'a' → bergerak
  });

  test('tetangga bereaksi saat node di-drag menjauh', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b')],
      edgeInputs: [(sourceId: 'a', targetId: 'b')],
    );
    for (var i = 0; i < 600; i++) {
      service.step();
    }
    final b = service.nodes.firstWhere((n) => n.id == 'b');
    final bBefore = b.position;

    final a = service.nodes.firstWhere((n) => n.id == 'a');
    service.beginDrag(a);
    service.dragTo(a, a.position + const Offset(1000, 0));
    for (var i = 0; i < 120; i++) {
      service.step();
    }

    expect(b.position, isNot(bBefore));
  });

  test('node tanpa link tidak terlempar jauh (bbox terbatas)', () {
    final service = GraphLayoutService();
    service.setGraph(
      nodeInputs: [_free('a'), _free('b'), _free('c')],
      edgeInputs: [(sourceId: 'a', targetId: 'b')], // 'c' terisolasi
    );

    for (var i = 0; i < 600; i++) {
      service.step();
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final node in service.nodes) {
      minX = min(minX, node.position.dx);
      minY = min(minY, node.position.dy);
      maxX = max(maxX, node.position.dx);
      maxY = max(maxY, node.position.dy);
    }
    // Node terisolasi hanya terdorong ~cutoff (3x ideal), tidak meledak ribuan
    // piksel seperti formula jarak-ideal lama.
    expect(max(maxX - minX, maxY - minY), lessThan(kIdealDistance * 8));
  });
}

import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/graph/application/services/graph_layout_service.dart';
import 'package:mesh_draft/features/graph/presentation/controllers/graph_controller.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';

/// Ukuran nominal CustomPaint/GestureDetector — sengaja jauh lebih besar dari
/// kWorldSize karena layout force-directed tidak dibatasi dan bisa menyebar
/// jauh (spike settle di ~5965x5498). Kalau terlalu kecil, node yang menyebar
/// keluar batas ini tidak menerima tap (area hit-test persis sebesar ini).
const double kCanvasSize = 20000;

/// Transform yang menaruh bounding-box graf (minX..maxX, minY..maxY) di tengah
/// [viewport], diskalakan agar muat (dengan padding), dibatasi [0.05, 1.0] —
/// batas atas 1.0 supaya graf mungil tidak di-zoom berlebihan, minScale supaya
/// graf raksasa tetap masuk layar. Fungsi murni supaya bisa diuji.
Matrix4 fitToViewportTransform({
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  required Size viewport,
}) {
  const padding = 48.0;
  final contentWidth = (maxX - minX) + 2 * (kNodeRadius + padding);
  final contentHeight = (maxY - minY) + 2 * (kNodeRadius + padding);
  final scale = min(
    viewport.width / contentWidth,
    viewport.height / contentHeight,
  ).clamp(0.05, 1.0).toDouble();
  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;
  return Matrix4.identity()
    ..translateByDouble(
      viewport.width / 2 - scale * centerX,
      viewport.height / 2 - scale * centerY,
      0,
      1,
    )
    ..scaleByDouble(scale, scale, scale, 1);
}

class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key, required this.onNodeTap});

  final void Function(String noteId) onNodeTap;

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<GraphView>
    with SingleTickerProviderStateMixin {
  final GraphLayoutService _layout = GraphLayoutService();
  final Map<String, TextPainter> _labels = {};

  late final AnimationController _ticker;

  // Transform awal fixed (scale 0.3, tanpa translate) — TIDAK dihitung dari
  // renderBox.size. Frame pertama bisa melaporkan viewport (0,0) dan meracuni
  // transform permanen (bug yang ditemukan di spike); scale tetap menghindari
  // kelas masalah itu.
  final TransformationController _transform = TransformationController(
    Matrix4.identity()..scaleByDouble(0.3, 0.3, 0.3, 1),
  );

  String _topologySignature = '';
  String _labelSignature = '';
  Color _labelColor = const Color(0xFF000000);
  bool _userInteracted = false;
  bool _needsInitialFit = true;

  // Interaksi node aktif (grab/drag). Saat tidak null, pan InteractiveViewer
  // dinonaktifkan supaya tidak bersaing dengan drag node di gesture arena.
  int? _activePointer;
  GraphNode? _grabbedNode;
  Offset _grabDownPosition = Offset.zero;
  bool _dragConfirmed = false;

  @override
  void initState() {
    super.initState();
    // AnimationController yang di-repeat() jadi ticker: nilai animasinya tidak
    // dipakai, hanya callback tiap frame untuk 1 langkah simulasi. Juga dipakai
    // sebagai `repaint:` CustomPaint supaya repaint terjadi tanpa setState()
    // (tanpa rebuild widget tree tiap frame).
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transform.dispose();
    for (final painter in _labels.values) {
      painter.dispose();
    }
    super.dispose();
  }

  void _onTick() {
    _layout.step();
    // Kamera: sekali bingkai penuh saat graf pertama muncul, lalu HANYA zoom-out
    // untuk memuat node yang menyebar — tidak pernah zoom-in saat graf memadat
    // (itu yang terasa "dihisap ke tengah"). Berhenti begitu user pan/zoom.
    if (!_userInteracted) {
      if (_needsInitialFit) {
        if (_fitCamera(zoomOutOnly: false)) _needsInitialFit = false;
      } else if (!_layout.isConverged) {
        _fitCamera(zoomOutOnly: true);
      }
    }
    // Hemat baterai: hentikan ticker begitu simulasi beku dan tidak sedang
    // drag. Dibangunkan lagi oleh _onPointerMove (drag) atau _applyData
    // (topologi baru).
    if (_layout.isConverged && _activePointer == null) {
      _ticker.stop();
    }
  }

  bool _fitCamera({required bool zoomOutOnly}) {
    final size = context.size;
    if (size == null || size.isEmpty || _layout.nodes.isEmpty) return false;

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final node in _layout.nodes) {
      minX = min(minX, node.position.dx);
      minY = min(minY, node.position.dy);
      maxX = max(maxX, node.position.dx);
      maxY = max(maxY, node.position.dy);
    }

    final target = fitToViewportTransform(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      viewport: size,
    );

    if (zoomOutOnly) {
      // Hanya perbesar bidang pandang (skala mengecil) untuk memuat node yang
      // menyebar; jangan zoom-in saat graf memadat — itu efek "dihisap".
      // Lerp supaya halus, dan ambang 0.98 supaya tidak menyentak tiap frame.
      final currentScale = _transform.value.getMaxScaleOnAxis();
      if (target.getMaxScaleOnAxis() >= currentScale * 0.98) return true;
      _transform.value = _lerpTransform(_transform.value, target, 0.12);
    } else {
      _transform.value = target;
    }
    return true;
  }

  Matrix4 _lerpTransform(Matrix4 current, Matrix4 target, double t) {
    final scale = lerpDouble(
      current.getMaxScaleOnAxis(),
      target.getMaxScaleOnAxis(),
      t,
    )!;
    final from = current.getTranslation();
    final to = target.getTranslation();
    return Matrix4.identity()
      ..translateByDouble(
        lerpDouble(from.x, to.x, t)!,
        lerpDouble(from.y, to.y, t)!,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _applyData(GraphData data) {
    // Label di-rebuild saat judul atau warna (tema) berubah — bukan tiap build.
    final labelSignature =
        '$_labelColor|${[for (final n in data.notes) '${n.id}:${n.title}'].join('|')}';
    if (labelSignature != _labelSignature) {
      _labelSignature = labelSignature;
      _rebuildLabels(data.notes);
    }

    // Rebuild fisika hanya saat topologi (himpunan id node + pasangan edge)
    // berubah — bukan tiap kali judul diedit — supaya edit judul tidak
    // memanaskan ulang simulasi yang sudah settle.
    final topology = _topologyOf(data);
    if (topology == _topologySignature) return;
    _topologySignature = topology;

    _layout.setGraph(
      nodeInputs: [
        for (final note in data.notes)
          (id: note.id, x: note.posX, y: note.posY),
      ],
      edgeInputs: [
        for (final link in data.links)
          (sourceId: link.sourceId, targetId: link.targetId),
      ],
    );
    if (!_ticker.isAnimating) _ticker.repeat();
  }

  String _topologyOf(GraphData data) {
    final ids = [for (final n in data.notes) n.id]..sort();
    final edges = [for (final l in data.links) '${l.sourceId}-${l.targetId}']
      ..sort();
    return '${ids.join(',')}|${edges.join(',')}';
  }

  void _rebuildLabels(List<Note> notes) {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
    for (final note in notes) {
      // Di-layout SEKALI di sini (saat data berubah), bukan tiap frame —
      // TextPainter.layout() 100x per frame membebani UI thread sia-sia.
      _labels[note.id] = TextPainter(
        text: TextSpan(
          text: note.title,
          style: TextStyle(
            color: _labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 120);
    }
  }

  // Hit-test node dalam koordinat "dunia". Toleransi membesar saat zoom-out
  // supaya target sentuh di layar tetap masuk akal — node kecil di layar saat
  // graf di-fit hampir mustahil dikenai kalau toleransinya tetap di ruang dunia.
  GraphNode? _hitNode(Offset worldPosition) {
    final scale = _transform.value.getMaxScaleOnAxis();
    return _layout.nodeAt(worldPosition, tolerance: 28 / scale);
  }

  // Pointer mendarat: kalau di atas node, klaim gesture ini untuk node (kunci
  // pan IV lewat setState) — deterministik, tanpa adu menang di gesture arena.
  // Kalau di area kosong, dibiarkan: InteractiveViewer yang pan.
  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    final node = _hitNode(_transform.toScene(event.localPosition));
    if (node == null) return;
    _activePointer = event.pointer;
    _grabbedNode = node;
    _grabDownPosition = event.localPosition;
    _dragConfirmed = false;
    setState(() {}); // panEnabled IV → false selama node dipegang
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final node = _grabbedNode!;
    if (!_dragConfirmed) {
      // Di bawah touch-slop diperlakukan sebagai tap, bukan drag — node belum
      // di-pin, jadi tap yang sekadar membuka detail tidak mengunci posisi.
      if ((event.localPosition - _grabDownPosition).distance <= kTouchSlop) {
        return;
      }
      _dragConfirmed = true;
      _userInteracted =
          true; // hentikan auto-fit kamera supaya tak melawan jari
      _layout.beginDrag(node);
    }
    _layout.dragTo(node, _transform.toScene(event.localPosition));
    if (!_ticker.isAnimating) _ticker.repeat();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    final node = _grabbedNode!;
    if (_dragConfirmed) {
      // Node tetap ter-pin di titik lepas; persist posisi supaya jadi jangkar
      // saat app dibuka ulang. Fire-and-forget: Drift memancarkan daftar baru,
      // tapi topologi tak berubah jadi setGraph tidak dipanggil ulang.
      ref
          .read(noteServiceProvider)
          .updateNotePosition(
            node.id,
            x: node.position.dx,
            y: node.position.dy,
          );
    } else {
      widget.onNodeTap(node.id);
    }
    _endPointer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _endPointer();
  }

  void _endPointer() {
    _layout.endDrag(); // keluar mode drag → simulasi normal (momentum) lanjut
    _activePointer = null;
    _grabbedNode = null;
    _dragConfirmed = false;
    setState(() {}); // panEnabled IV → true lagi
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _labelColor = scheme.onSurface;
    // Sinkronkan simulasi dengan data terbaru. Mutasi service, bukan setState —
    // repaint tetap didorong ticker. Idempoten: setGraph hanya jalan saat
    // topologi berubah (lihat _applyData). Null = kedua stream belum siap.
    final data = ref.watch(graphControllerProvider);
    if (data != null) _applyData(data);

    // Listener menerima SEMUA event pointer tanpa ikut gesture arena, jadi drag
    // node tidak beradu-menang dengan pan/zoom IV (yang non-deterministik).
    // Saat jari memegang node, panEnabled IV dimatikan sehingga hanya drag node
    // yang jalan; di area kosong panEnabled aktif dan IV yang pan.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        transformationController: _transform,
        // Konten (kCanvasSize) jauh lebih besar dari viewport secara sengaja —
        // constrained:false wajib, kalau tidak InteractiveViewer memaksa canvas
        // diperas masuk viewport (layar jadi kosong).
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.05,
        maxScale: 5,
        panEnabled: _activePointer == null,
        onInteractionStart: (_) => _userInteracted = true,
        child: CustomPaint(
          size: const Size(kCanvasSize, kCanvasSize),
          painter: _GraphPainter(
            layout: _layout,
            labels: _labels,
            nodeColor: MeshColors.node,
            edgeColor: MeshColors.edge,
            repaint: _ticker,
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.layout,
    required this.labels,
    required this.nodeColor,
    required this.edgeColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GraphLayoutService layout;
  final Map<String, TextPainter> labels;
  final Color nodeColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (final edge in layout.edges) {
      canvas.drawLine(
        layout.nodes[edge.a].position,
        layout.nodes[edge.b].position,
        edgePaint,
      );
    }

    final nodePaint = Paint()..color = nodeColor;
    for (final node in layout.nodes) {
      canvas.drawCircle(node.position, kNodeRadius, nodePaint);
      final label = labels[node.id];
      if (label != null) {
        label.paint(
          canvas,
          node.position + Offset(-label.width / 2, kNodeRadius + 4),
        );
      }
    }
  }

  // Repaint didorong oleh `repaint:` (ticker); nodes dimutasi in-place. Selalu
  // true supaya benar meskipun delegate baru dibuat (mis. saat tema berubah).
  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

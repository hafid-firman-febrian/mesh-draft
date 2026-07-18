import 'dart:math';
import 'dart:ui' show Offset;

const int kSeed = 42;

const double kNodeRadius = 16;

// Jarak ideal antar node terhubung, TETAP — bukan sqrt(area/n) ala FR klasik.
// Formula lama membuat graf kecil menyebar sangat jauh (2 node → ~3536), jadi
// setelah fit node mengecil jadi titik dan node tanpa link (yang terdorong ke
// cutoff ~3x ideal) terlempar ke luar layar. Simulasi force scale-invariant
// (repulsi ∝ ideal²/d, atraksi ∝ d²/ideal), jadi skala absolut kecil ini tidak
// mengubah keseimbangan yang sudah di-tune — hanya mengecilkan hasil akhirnya,
// dan karena radius node absolut, node jadi lebih besar di layar setelah fit.
const double kIdealDistance = 200;

// Suhu awal = jarak ideal. Di spike (n=100) temp == ideal secara kebetulan
// numerik; kForceScale di-tune untuk rasio itu, jadi rasio itu dipertahankan.
const double kInitialTemperature = kIdealDistance;

// Batas kecepatan node bebas (px/frame) saat ada node lain sedang di-drag.
// Selama drag node bergerak TANPA momentum (lihat step) supaya tidak bergetar;
// cap ini hanya mencegah lompatan besar saat node ditarik jauh. Soal rasa —
// naikkan agar tetangga menyusul lebih gesit, turunkan bila terasa meloncat.
const double kDragMaxSpeed = 30;

// Fraksi langkah gradient-descent per frame saat mengikuti node yang di-drag.
// Sengaja kecil: langkah besar membuat node berderajat tinggi (banyak link)
// melewati titik keseimbangan → sisa getar. kDragMaxSpeed sudah menangani
// kecepatan saat drag cepat, jadi faktor kecil ini nyaris tak mengurangi
// responsivitas. Soal rasa — turunkan bila masih ada getar, naikkan bila
// tetangga terasa lamban menyusul.
const double kDragFollowFactor = 0.02;

const double kCoolingFactor = 0.98;

const double kTemperatureCutoff = 0.05;

const double kVelocityDamping = 0.9;

const double kMinDistance = 1.0;

const double kForceScale = 0.08;

const double kMinSpawnDistance = kNodeRadius * 3;

// Batas jarak repulsi = faktor ini × ideal. Selain memangkas beban O(n²) dari
// pasangan jauh, ini juga menentukan seberapa jauh node TANPA link berhenti:
// tanpa gaya tarik, mereka terdorong repulsi sampai batas ini lalu diam. 3×
// bikin node tak-terhubung ~3× lebih jauh dari yang terhubung (timpang); 1.5×
// merapatkannya tanpa mengubah jarak node terhubung (repulsi masih aktif di
// jarak ideal karena ideal < cutoff). Turunkan untuk lebih rapat lagi (jangan
// ≤ ~1.2× — repulsi butuh margin di atas ideal agar cluster tidak kolaps).
const double kRepulsionCutoffFactor = 1.5;

typedef GraphNodeInput = ({String id, double? x, double? y});

typedef GraphEdgeInput = ({String sourceId, String targetId});

class GraphNode {
  GraphNode({required this.id, required this.position, required this.pinned});

  final String id;
  Offset position;
  Offset velocity = Offset.zero;

  // Mutable: node bebas dikunci saat di-drag, lalu tetap terkunci di titik
  // lepas (posisi jadi jangkar untuk simulasi tetangga).
  bool pinned;
}

class GraphEdge {
  const GraphEdge(this.a, this.b);

  final int a;
  final int b;
}

class GraphLayoutService {
  final Random _rng = Random(kSeed);

  final List<GraphNode> nodes = [];
  final List<GraphEdge> edges = [];

  double _temperature = 0;
  double _idealDistance = 1;
  double _repulsionCutoff = double.infinity;
  bool _dragging = false;
  int _draggedIndex = -1;
  final Set<int> _draggedNeighbors = {};

  // Konvergen = sudah dingin DAN tidak sedang di-drag. Saat drag, meski suhu
  // nol, simulasi tetap aktif menyusul node yang ditarik.
  bool get isConverged => _temperature <= 0 && !_dragging;

  double get temperature => _temperature;

  void setGraph({
    required List<GraphNodeInput> nodeInputs,
    required List<GraphEdgeInput> edgeInputs,
  }) {
    final previous = {for (final node in nodes) node.id: node};
    final placed = <GraphNode>[];

    // Sisi area spawn: n node dengan kerapatan ~1 per kIdealDistance² → node
    // lahir kira-kira sejauh jarak ideal, dan (untuk graf kecil) di dalam radius
    // cutoff satu sama lain, sehingga node tanpa link pun terdorong ke jarak
    // terbatas alih-alih tertinggal jauh di titik spawn acaknya.
    final spawnSize = kIdealDistance * sqrt(max(nodeInputs.length, 1));

    for (final input in nodeInputs) {
      if (input.x != null && input.y != null) {
        placed.add(
          GraphNode(
            id: input.id,
            position: Offset(input.x!, input.y!),
            pinned: true,
          ),
        );
        continue;
      }
      final existing = previous[input.id];
      if (existing != null) {
        placed.add(
          GraphNode(id: input.id, position: existing.position, pinned: false)
            ..velocity = existing.velocity,
        );
        continue;
      }
      placed.add(
        GraphNode(
          id: input.id,
          position: _spawnPosition(placed, spawnSize),
          pinned: false,
        ),
      );
    }

    nodes
      ..clear()
      ..addAll(placed);

    final indexById = {for (var i = 0; i < nodes.length; i++) nodes[i].id: i};
    edges.clear();
    for (final edge in edgeInputs) {
      final a = indexById[edge.sourceId];
      final b = indexById[edge.targetId];
      if (a != null && b != null && a != b) {
        edges.add(GraphEdge(a, b));
      }
    }

    _idealDistance = kIdealDistance;
    _repulsionCutoff = kIdealDistance * kRepulsionCutoffFactor;

    reheat();
  }

  void reheat() {
    _temperature = kInitialTemperature;
  }

  GraphNode? nodeAt(Offset worldPosition, {double tolerance = 8}) {
    final reach = kNodeRadius + tolerance;
    GraphNode? nearest;
    var nearestDistance = double.infinity;
    for (final node in nodes) {
      final distance = (node.position - worldPosition).distance;
      if (distance <= reach && distance < nearestDistance) {
        nearest = node;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  // Mulai men-drag [node]: kunci (velocity nol, tak digerakkan simulasi) dan
  // aktifkan mode drag. Selama mode ini, node bebas mengikuti TANPA momentum
  // (anti-getar, lihat step) dan simulasi tetap jalan meski suhu nol.
  void beginDrag(GraphNode node) {
    node.pinned = true;
    node.velocity = Offset.zero;
    _dragging = true;
    _draggedIndex = nodes.indexOf(node);
    _draggedNeighbors.clear();
    for (final e in edges) {
      if (e.a == _draggedIndex) _draggedNeighbors.add(e.b);
      if (e.b == _draggedIndex) _draggedNeighbors.add(e.a);
    }
  }

  void endDrag() {
    _dragging = false;
    _draggedIndex = -1;
    _draggedNeighbors.clear();
  }

  // Tempel node ke posisi jari persis. Tetangga menyusul lewat step() dalam mode
  // drag (gradient-descent tanpa momentum) — tak boleh reheat di sini: menambah
  // energi tiap frame justru sumber getaran.
  void dragTo(GraphNode node, Offset worldPosition) {
    node.position = worldPosition;
  }

  Offset _spawnPosition(List<GraphNode> placed, double spawnSize) {
    Offset random() => Offset(
      kNodeRadius + _rng.nextDouble() * (spawnSize - 2 * kNodeRadius),
      kNodeRadius + _rng.nextDouble() * (spawnSize - 2 * kNodeRadius),
    );
    var pos = random();
    var attempts = 0;
    while (attempts < 50 &&
        placed.any((n) => (n.position - pos).distance < kMinSpawnDistance)) {
      pos = random();
      attempts++;
    }
    return pos;
  }

  void step() {
    // Saat drag, simulasi tetap jalan meski suhu nol supaya tetangga terus
    // mengikuti node yang ditarik.
    if (_temperature <= 0 && !_dragging) return;

    final n = nodes.length;
    if (n == 0) return;
    final disp = List<Offset>.filled(n, Offset.zero);

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var delta = nodes[i].position - nodes[j].position;
        var dist = delta.distance;
        if (dist > _repulsionCutoff) continue;
        if (dist < 0.001) {
          delta = Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5);
          dist = delta.distance;
        }

        final safeDist = max(dist, kMinDistance);
        final force = (_idealDistance * _idealDistance) / safeDist;
        final push = delta / dist * force;
        disp[i] += push;
        disp[j] -= push;
      }
    }

    for (final e in edges) {
      var delta = nodes[e.b].position - nodes[e.a].position;
      var dist = delta.distance;
      if (dist < 0.001) dist = 0.001;
      final force = (dist * dist) / _idealDistance;
      final pull = delta / dist * force;
      disp[e.a] += pull;
      disp[e.b] -= pull;
    }

    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      if (node.pinned) {
        node.velocity = Offset.zero;
        continue;
      }
      if (_dragging) {
        node.velocity = Offset.zero;
        // Hanya gerakkan node yang terpengaruh node yang di-drag: tetangga
        // langsung (edge) atau yang cukup dekat sehingga terdorong repulsi. Graf
        // membeku di suhu nol, BUKAN di keseimbangan gaya sempurna — sisa gaya
        // beku itu ada di semua node. Tanpa gate ini, menjalankan step() saat
        // drag melepas sisa gaya tsb dan node jauh yang tak terkait ikut bergerak.
        final influenced = _draggedIndex < 0 ||
            _draggedIndex >= n ||
            _draggedNeighbors.contains(i) ||
            (node.position - nodes[_draggedIndex].position).distance <=
                _repulsionCutoff;
        if (!influenced) continue;
        // Gerak TANPA momentum (velocity tak diakumulasi) → gradient-descent satu
        // langkah, tanpa overshoot/getar. Faktor kecil (kDragFollowFactor)
        // mencegah node berderajat tinggi overshoot; cap kDragMaxSpeed menahan
        // lompatan besar saat node ditarik jauh.
        var move = disp[i] * kDragFollowFactor;
        final speed = move.distance;
        if (speed > kDragMaxSpeed) {
          move = move / speed * kDragMaxSpeed;
        }
        node.position += move;
        continue;
      }
      var v = (node.velocity + disp[i] * kForceScale) * kVelocityDamping;
      final speed = v.distance;

      if (speed > _temperature) {
        v = v / speed * _temperature;
      }
      node.velocity = v;
      node.position += v;
    }

    // Cooling hanya saat tidak drag: selama drag suhu dibiarkan (gerak diatur
    // gradient-descent, bukan suhu), lalu setelah endDrag simulasi normal
    // melanjutkan cooling ke nol seperti biasa.
    if (!_dragging) {
      _temperature *= kCoolingFactor;
      if (_temperature < kTemperatureCutoff) {
        _temperature = 0;
      }
    }
  }
}

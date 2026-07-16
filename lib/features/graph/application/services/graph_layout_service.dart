import 'dart:math';
import 'dart:ui' show Offset;

const int kSeed = 42;

const double kWorldSize = 5000;

const double kNodeRadius = 16;

const double kInitialTemperature = kWorldSize / 10;

const double kCoolingFactor = 0.98;

const double kTemperatureCutoff = 0.05;

const double kVelocityDamping = 0.9;

const double kMinDistance = 1.0;

const double kForceScale = 0.08;

const double kMinSpawnDistance = kNodeRadius * 3;

const double kRepulsionCutoffFactor = 3.0;

typedef GraphNodeInput = ({String id, double? x, double? y});

typedef GraphEdgeInput = ({String sourceId, String targetId});

class GraphNode {
  GraphNode({required this.id, required this.position, required this.pinned});

  final String id;
  Offset position;
  Offset velocity = Offset.zero;

  final bool pinned;
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
  double _lastMaxSpeed = 0;

  bool get isConverged => _temperature <= 0;

  double get temperature => _temperature;

  double get lastMaxSpeed => _lastMaxSpeed;

  void setGraph({
    required List<GraphNodeInput> nodeInputs,
    required List<GraphEdgeInput> edgeInputs,
  }) {
    final previous = {for (final node in nodes) node.id: node};
    final placed = <GraphNode>[];

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
          position: _spawnPosition(placed),
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

    _idealDistance = nodes.isEmpty
        ? 1
        : sqrt((kWorldSize * kWorldSize) / nodes.length);
    _repulsionCutoff = _idealDistance * kRepulsionCutoffFactor;

    reheat();
  }

  void reheat() {
    _temperature = kInitialTemperature;
  }

  Offset _spawnPosition(List<GraphNode> placed) {
    Offset random() => Offset(
      kNodeRadius + _rng.nextDouble() * (kWorldSize - 2 * kNodeRadius),
      kNodeRadius + _rng.nextDouble() * (kWorldSize - 2 * kNodeRadius),
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
    if (_temperature <= 0) return;

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

    var maxSpeed = 0.0;
    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      if (node.pinned) {
        node.velocity = Offset.zero;
        continue;
      }
      var v = (node.velocity + disp[i] * kForceScale) * kVelocityDamping;
      final speed = v.distance;

      if (speed > _temperature) {
        v = v / speed * _temperature;
      }
      node.velocity = v;
      node.position += v;
      maxSpeed = max(maxSpeed, v.distance);
    }
    _lastMaxSpeed = maxSpeed;

    _temperature *= kCoolingFactor;
    if (_temperature < kTemperatureCutoff) {
      _temperature = 0;
    }
  }
}

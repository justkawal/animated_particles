import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import '../config/enums.dart';

/// Holds particle state and advances the simulation each step.
/// Uses flat [Float32List] arrays (structure-of-arrays) for speed.
class ParticleEngine {
  ParticleEngine();

  int _capacity = 0;
  int _count = 0;

  // Interleaved x,y positions; everything else is one value per particle.
  Float32List _pos = Float32List(0);
  Float32List _velX = Float32List(0);
  Float32List _velY = Float32List(0);
  Float32List _tgtX = Float32List(0);
  Float32List _tgtY = Float32List(0);

  Float32List _pointsView = Float32List(0);

  /// Number of live particles.
  int get count => _count;

  /// Interleaved x,y positions ready for `drawRawPoints`.
  Float32List get points => _pointsView;

  /// Grows the backing arrays when more particles are needed.
  void _ensureCapacity(int n) {
    if (n <= _capacity) return;
    _capacity = n;
    _pos = Float32List(n * 2);
    _velX = Float32List(n);
    _velY = Float32List(n);
    _tgtX = Float32List(n);
    _tgtY = Float32List(n);
  }

  /// Re-points the public view at the live slice of the position buffer.
  void _refreshView() {
    _pointsView = Float32List.view(_pos.buffer, 0, _count * 2);
  }

  /// Creates [n] particles at random start positions for the given size.
  void spawn(int n, Size size, math.Random rng) {
    _ensureCapacity(n);
    _count = n;
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < n; i++) {
      final xi = i << 1;
      _pos[xi] = rng.nextDouble() * w;
      _pos[xi + 1] = rng.nextDouble() * w;
      _velX[i] = 0.0;
      _velY[i] = 0.0;
      _tgtX[i] = rng.nextDouble() * w;
      _tgtY[i] = rng.nextDouble() * h;
    }
    _refreshView();
  }

  /// Sends every particle fleeing toward the given [position] edge, spread
  /// out along it, ready to reform afterward.
  void escapeAll(EscapePosition position, Size size, math.Random rng) {
    final w = size.width;
    final h = size.height;
    switch (position) {
      case EscapePosition.left:
        for (var i = 0; i < _count; i++) {
          _tgtX[i] = 0.0;
          _tgtY[i] = rng.nextDouble() * h;
        }
      case EscapePosition.right:
        for (var i = 0; i < _count; i++) {
          _tgtX[i] = w;
          _tgtY[i] = rng.nextDouble() * h;
        }
      case EscapePosition.top:
        for (var i = 0; i < _count; i++) {
          _tgtX[i] = rng.nextDouble() * w;
          _tgtY[i] = 0.0;
        }
      case EscapePosition.bottom:
        for (var i = 0; i < _count; i++) {
          _tgtX[i] = rng.nextDouble() * w;
          _tgtY[i] = h;
        }
    }
  }

  /// Points particles at the given target offsets (one per particle).
  void assignTargets(List<Offset> targets) {
    final m = math.min(_count, targets.length);
    for (var i = 0; i < m; i++) {
      final t = targets[i];
      _tgtX[i] = t.dx;
      _tgtY[i] = t.dy;
    }
  }

  /// Advances every particle one step using arrive-at-target steering,
  /// plus a flee force pushing away from the drag point when active.
  void step({
    required double maxSpeed,
    required double maxForce,
    required double arrivalRadius,
    required double fleeRadius,
    required bool dragging,
    required double dragX,
    required double dragY,
  }) {
    final pos = _pos;
    final velX = _velX;
    final velY = _velY;
    final tgtX = _tgtX;
    final tgtY = _tgtY;
    final n = _count;

    // Precompute squared limits to avoid sqrt where possible.
    final maxForce2 = maxForce * maxForce;
    final fleeR2 = fleeRadius * fleeRadius;
    final invArrival = maxSpeed / arrivalRadius;

    for (var i = 0; i < n; i++) {
      final xi = i << 1;
      final yi = xi + 1;
      final px = pos[xi];
      final py = pos[yi];
      final vx = velX[i];
      final vy = velY[i];

      var accX = 0.0;
      var accY = 0.0;
      // Steer toward the target, easing off within the arrival radius.
      var dx = tgtX[i] - px;
      var dy = tgtY[i] - py;
      var d2 = dx * dx + dy * dy;
      if (d2 > 1e-12) {
        final d = math.sqrt(d2);
        final speed = d < arrivalRadius ? d * invArrival : maxSpeed;
        final k = speed / d;
        var sx = dx * k - vx;
        var sy = dy * k - vy;
        final ms2 = sx * sx + sy * sy;
        if (ms2 > maxForce2) {
          final f = maxForce / math.sqrt(ms2);
          sx *= f;
          sy *= f;
        }
        accX = sx;
        accY = sy;
      }

      // Flee from the drag point when it is within range.
      if (dragging) {
        final rdx = dragX - px;
        final rdy = dragY - py;
        final rd2 = rdx * rdx + rdy * rdy;
        if (rd2 < fleeR2 && rd2 > 1e-12) {
          final rd = math.sqrt(rd2);
          final rk = -maxSpeed / rd;
          var fsx = rdx * rk - vx;
          var fsy = rdy * rk - vy;
          final fms2 = fsx * fsx + fsy * fsy;
          if (fms2 > maxForce2) {
            final ff = maxForce / math.sqrt(fms2);
            fsx *= ff;
            fsy *= ff;
          }
          accX += fsx;
          accY += fsy;
        }
      }

      // Integrate: move by current velocity, then apply acceleration.
      pos[xi] = px + vx;
      pos[yi] = py + vy;
      velX[i] = vx + accX;
      velY[i] = vy + accY;
    }
  }
}

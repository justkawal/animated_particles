import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:animated_particles/src/engine/particle_engine.dart';

void main() {
  group('ParticleEngine', () {
    test('spawn allocates the requested number of particles', () {
      final engine = ParticleEngine();
      engine.spawn(500, const Size(400, 800), math.Random(1));
      expect(engine.count, 500);
      expect(engine.points.length, 1000);
    });

    test('a particle converges to its assigned target over time', () {
      final engine = ParticleEngine();
      engine.spawn(1, const Size(400, 800), math.Random(2));
      const target = Offset(200, 300);
      engine.assignTargets(const [target]);

      for (var i = 0; i < 300; i++) {
        engine.step(
          maxSpeed: 20,
          maxForce: 3,
          arrivalRadius: 100,
          fleeRadius: 40,
          dragging: false,
          dragX: 0,
          dragY: 0,
        );
      }

      final dx = engine.points[0] - target.dx;
      final dy = engine.points[1] - target.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      expect(dist, lessThan(2.0), reason: 'particle should arrive at target');
    });

    test('assignTargets only retargets the first N; count unchanged', () {
      final engine = ParticleEngine();
      engine.spawn(10, const Size(400, 800), math.Random(3));
      engine.assignTargets(const [Offset(10, 10), Offset(20, 20)]);
      engine.step(
        maxSpeed: 20,
        maxForce: 3,
        arrivalRadius: 100,
        fleeRadius: 40,
        dragging: false,
        dragX: 0,
        dragY: 0,
      );
      expect(engine.count, 10);
    });

    test('positions never become NaN even when already on target', () {
      final engine = ParticleEngine();
      engine.spawn(1, const Size(400, 800), math.Random(4));
      engine.assignTargets([Offset(engine.points[0], engine.points[1])]);
      for (var i = 0; i < 50; i++) {
        engine.step(
          maxSpeed: 20,
          maxForce: 3,
          arrivalRadius: 100,
          fleeRadius: 40,
          dragging: false,
          dragX: 0,
          dragY: 0,
        );
      }
      expect(engine.points[0].isNaN, isFalse);
      expect(engine.points[1].isNaN, isFalse);
    });
  });
}

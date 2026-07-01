import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'enums.dart';

/// Immutable settings that control particle motion and appearance.
@immutable
class ParticleFieldConfig {
  const ParticleFieldConfig({
    this.maxSpeed = 20.0,
    this.maxForce = 3.0,
    this.arrivalRadius = 100.0,
    this.fleeRadius = 40.0,
    this.escapePosition = EscapePosition.bottom,
    this.reformDelay = const Duration(milliseconds: 100),
    this.color = const Color(0xFFFFFFFF),
    this.particleSize = 2.0,
    this.shape = ParticleShape.square,
    this.antiAlias = false,
    this.particleCount,
    this.placement = PlacementMode.fit,
    this.fillFraction = 0.78,
    this.alignment = const Alignment(0.0, -0.35),
    this.margin = 16.0,
  })  : assert(maxSpeed > 0),
        assert(maxForce > 0),
        assert(arrivalRadius > 0),
        assert(particleSize > 0),
        assert(fillFraction > 0 && fillFraction <= 1);

  /// Top speed a particle can travel, in pixels per step.
  final double maxSpeed;

  /// Max steering force applied per step (controls turn sharpness).
  final double maxForce;

  /// Distance from the target at which particles start slowing down.
  final double arrivalRadius;

  /// Particles within this distance of the drag point are pushed away.
  final double fleeRadius;

  /// Which edge particles flee to before reforming into a shape.
  final EscapePosition escapePosition;

  /// Delay between escaping and moving to the new target.
  final Duration reformDelay;

  /// Particle color.
  final Color color;

  /// Particle diameter/side length, in pixels.
  final double particleSize;

  /// Whether particles are drawn as squares or circles.
  final ParticleShape shape;

  /// Whether to anti-alias particles (smoother but slower).
  final bool antiAlias;

  /// Fixed particle count; when null it follows the largest target.
  final int? particleCount;

  /// How the sampled shape is positioned within the field.
  final PlacementMode placement;

  /// Fraction of the available space the shape fills (0–1).
  final double fillFraction;

  /// Where the shape sits within the field.
  final Alignment alignment;

  /// Empty space kept around the shape, in pixels.
  final double margin;

  /// Returns a copy with the given fields replaced.
  ParticleFieldConfig copyWith({
    double? maxSpeed,
    double? maxForce,
    double? arrivalRadius,
    double? fleeRadius,
    EscapePosition? escapePosition,
    Duration? reformDelay,
    Color? color,
    double? particleSize,
    ParticleShape? shape,
    bool? antiAlias,
    int? particleCount,
    PlacementMode? placement,
    double? fillFraction,
    Alignment? alignment,
    double? margin,
  }) {
    return ParticleFieldConfig(
      maxSpeed: maxSpeed ?? this.maxSpeed,
      maxForce: maxForce ?? this.maxForce,
      arrivalRadius: arrivalRadius ?? this.arrivalRadius,
      fleeRadius: fleeRadius ?? this.fleeRadius,
      escapePosition: escapePosition ?? this.escapePosition,
      reformDelay: reformDelay ?? this.reformDelay,
      color: color ?? this.color,
      particleSize: particleSize ?? this.particleSize,
      shape: shape ?? this.shape,
      antiAlias: antiAlias ?? this.antiAlias,
      particleCount: particleCount ?? this.particleCount,
      placement: placement ?? this.placement,
      fillFraction: fillFraction ?? this.fillFraction,
      alignment: alignment ?? this.alignment,
      margin: margin ?? this.margin,
    );
  }
}

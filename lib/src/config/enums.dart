/// Which edge particles flee to before reforming into a target shape.
enum EscapePosition {
  /// Flee toward the left edge.
  left,

  /// Flee toward the right edge.
  right,

  /// Flee toward the top edge.
  top,

  /// Flee toward the bottom edge.
  bottom,
}

/// Shape used to draw each particle.
enum ParticleShape {
  square,
  circle,
}

/// How a sampled shape is positioned inside the field.
enum PlacementMode {
  /// Use the sampled coordinates as-is (only centered horizontally).
  raw,

  /// Scale and align the shape to fit the field.
  fit,
}

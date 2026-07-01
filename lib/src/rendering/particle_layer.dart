import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../config/enums.dart';
import '../engine/particle_engine.dart';

/// Render-object widget that paints the engine's particles.
class ParticleLayer extends LeafRenderObjectWidget {
  const ParticleLayer({
    super.key,
    required this.engine,
    required this.repaint,
    required this.color,
    required this.particleSize,
    required this.shape,
    required this.antiAlias,
  });

  final ParticleEngine engine;
  final Listenable repaint;
  final Color color;
  final double particleSize;
  final ParticleShape shape;
  final bool antiAlias;

  @override
  RenderParticleLayer createRenderObject(BuildContext context) {
    return RenderParticleLayer(
      engine: engine,
      repaint: repaint,
      color: color,
      particleSize: particleSize,
      shape: shape,
      antiAlias: antiAlias,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderParticleLayer renderObject) {
    renderObject
      ..engine = engine
      ..repaint = repaint
      ..color = color
      ..particleSize = particleSize
      ..shape = shape
      ..antiAlias = antiAlias;
  }
}

/// Render box that draws all particles in one `drawRawPoints` call and
/// repaints whenever [repaint] fires.
class RenderParticleLayer extends RenderBox {
  RenderParticleLayer({
    required ParticleEngine engine,
    required Listenable repaint,
    required Color color,
    required double particleSize,
    required ParticleShape shape,
    required bool antiAlias,
  })  : _engine = engine,
        _repaint = repaint,
        _color = color,
        _particleSize = particleSize,
        _shape = shape,
        _antiAlias = antiAlias {
    _repaint.addListener(markNeedsPaint);
    _rebuildPaint();
  }

  ParticleEngine _engine;
  ParticleEngine get engine => _engine;
  set engine(ParticleEngine value) {
    if (identical(_engine, value)) return;
    _engine = value;
    markNeedsPaint();
  }

  Listenable _repaint;
  Listenable get repaint => _repaint;
  set repaint(Listenable value) {
    if (identical(_repaint, value)) return;
    _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    _rebuildPaint();
    markNeedsPaint();
  }

  double _particleSize;
  double get particleSize => _particleSize;
  set particleSize(double value) {
    if (_particleSize == value) return;
    _particleSize = value;
    _rebuildPaint();
    markNeedsPaint();
  }

  ParticleShape _shape;
  ParticleShape get shape => _shape;
  set shape(ParticleShape value) {
    if (_shape == value) return;
    _shape = value;
    _rebuildPaint();
    markNeedsPaint();
  }

  bool _antiAlias;
  bool get antiAlias => _antiAlias;
  set antiAlias(bool value) {
    if (_antiAlias == value) return;
    _antiAlias = value;
    _rebuildPaint();
    markNeedsPaint();
  }

  late Paint _paint;

  /// Rebuilds the shared paint; particles are points, so size maps to
  /// stroke width and shape to the stroke cap (round = circle).
  void _rebuildPaint() {
    _paint = Paint()
      ..color = _color
      ..strokeWidth = _particleSize
      ..strokeCap =
          _shape == ParticleShape.circle ? StrokeCap.round : StrokeCap.square
      ..isAntiAlias = _antiAlias;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final count = _engine.count;
    if (count == 0) return;
    final canvas = context.canvas;
    // Translate only when not at the origin, then draw every point at once.
    final translated = offset != Offset.zero;
    if (translated) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
    }
    canvas.drawRawPoints(ui.PointMode.points, _engine.points, _paint);
    if (translated) canvas.restore();
  }
}

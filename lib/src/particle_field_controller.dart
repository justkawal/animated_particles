import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'config/enums.dart';
import 'config/particle_field_config.dart';
import 'engine/particle_engine.dart';
import 'targets/particle_target.dart';
import 'targets/pixel_sampler.dart';

/// Lightweight notifier used to trigger repaints without rebuilding widgets.
class _RepaintNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Drives the simulation: holds targets, runs the ticker, and exposes
/// methods for switching shapes, escaping, and handling drag input.
class ParticleFieldController extends ChangeNotifier {
  ParticleFieldController({
    ParticleFieldConfig config = const ParticleFieldConfig(),
    math.Random? random,
  })  : _config = config,
        _rng = random ?? math.Random();

  // Fixed-timestep simulation running at 30 Hz, capped at 5 catch-up steps.
  static const double _simHz = 30.0;
  static const double _simDt = 1.0 / _simHz;
  static const int _maxSubSteps = 5;

  final ParticleEngine _engine = ParticleEngine();
  final _RepaintNotifier _repaint = _RepaintNotifier();
  final math.Random _rng;

  /// Registered targets, keyed by name.
  final Map<String, SampledTemplate> _templates = <String, SampledTemplate>{};

  Ticker? _ticker;
  ParticleFieldConfig _config;
  Size _size = Size.zero;
  bool _started = false;
  String? _activeKey;

  // Current drag/pointer position used by the flee behavior.
  bool _dragging = false;
  double _dragX = 0.0;
  double _dragY = 0.0;

  // Accumulator state for the fixed-timestep loop.
  Duration _lastElapsed = Duration.zero;
  bool _hasLast = false;
  double _accumulator = 0.0;

  // Targets to apply after the reform delay has elapsed.
  List<Offset>? _pendingTargets;
  int _pendingStepsLeft = 0;

  /// Listenable that fires once per simulated frame; drives repaints.
  Listenable get repaint => _repaint;

  /// The underlying particle engine (positions for painting).
  ParticleEngine get engine => _engine;

  /// Current configuration.
  ParticleFieldConfig get config => _config;

  /// Number of active particles.
  int get particleCount => _engine.count;

  /// Key of the currently displayed target, if any.
  String? get activeKey => _activeKey;

  /// Names of all registered targets.
  Iterable<String> get keys => _templates.keys;

  /// Whether the simulation ticker is currently running.
  bool get isRunning => _ticker?.isActive ?? false;

  /// Replaces the config, re-spawning particles if the count changed.
  set config(ParticleFieldConfig value) {
    final oldCount = _resolveCount();
    _config = value;
    if (_resolveCount() != oldCount) {
      _ensureParticles();
    }
    notifyListeners();
  }

  /// Connects the ticker to a [TickerProvider]; call from the widget.
  void attach(TickerProvider vsync) {
    _ticker ??= vsync.createTicker(_onTick);
    if (_started && !(_ticker!.isActive)) {
      _ticker!.start();
    }
  }

  /// Updates the field size and re-places the active target's points.
  void setSize(Size size) {
    if (size.isEmpty || size == _size) return;
    final firstSize = _size.isEmpty;
    _size = size;
    if (firstSize) {
      _ensureParticles();
    } else {
      final key = _activeKey;
      if (key != null && _templates.containsKey(key)) {
        _engine.assignTargets(_placePoints(_templates[key]!, size));
      }
    }
  }

  /// Resolves and registers a single target under [key].
  Future<void> addTarget(String key, ParticleTarget target) async {
    final sampled = await target.resolve();
    _templates[key] = sampled;
    _ensureParticles();
    notifyListeners();
  }

  /// Resolves and registers several targets at once.
  Future<void> addTargets(Map<String, ParticleTarget> targets) async {
    for (final entry in targets.entries) {
      _templates[entry.key] = await entry.value.resolve();
    }
    _ensureParticles();
    notifyListeners();
  }

  /// Removes the target registered under [key].
  void removeTarget(String key) {
    if (_templates.remove(key) != null) {
      if (_activeKey == key) _activeKey = null;
      notifyListeners();
    }
  }

  /// Switches to the target [key]: particles flee to the configured escape
  /// position first, then reform after [ParticleFieldConfig.reformDelay].
  void changeTarget(String key) {
    final template = _templates[key];
    if (template == null) {
      throw ArgumentError.value(key, 'key', 'No template registered');
    }
    _activeKey = key;
    if (_size.isEmpty) return;

    _engine.escapeAll(_config.escapePosition, _size, _rng);
    _pendingTargets = _placePoints(template, _size);
    _pendingStepsLeft = math.max(
      1,
      (_config.reformDelay.inMicroseconds / 1e6 * _simHz).round(),
    );
  }

  /// Sends particles fleeing to the configured escape position and cancels
  /// any pending reform.
  void escape() {
    if (_size.isEmpty) return;
    _engine.escapeAll(_config.escapePosition, _size, _rng);
    _pendingTargets = null;
  }

  /// Sets (or clears, when null) the drag point particles flee from.
  void setDragPoint(Offset? local) {
    if (local == null) {
      _dragging = false;
    } else {
      _dragging = true;
      _dragX = local.dx;
      _dragY = local.dy;
    }
  }

  /// Starts the simulation.
  void start() {
    _started = true;
    if (_ticker != null && !_ticker!.isActive) _ticker!.start();
  }

  /// Stops the simulation.
  void stop() {
    _started = false;
    _ticker?.stop();
  }

  /// Particle count: explicit if set, otherwise the largest target.
  int _resolveCount() {
    final explicit = _config.particleCount;
    if (explicit != null) return explicit;
    var maxN = 0;
    for (final t in _templates.values) {
      if (t.length > maxN) maxN = t.length;
    }
    return maxN;
  }

  /// (Re)spawns particles to match the resolved count and starts ticking.
  void _ensureParticles() {
    final count = _resolveCount();
    if (count <= 0 || _size.isEmpty) return;
    if (_engine.count != count) {
      _engine.spawn(count, _size, _rng);
    }
    if (!_started) {
      start();
    } else if (_ticker != null && !_ticker!.isActive) {
      _ticker!.start();
    }
  }

  /// Maps a sampled template's points into field coordinates, scaling and
  /// aligning them per the placement config.
  List<Offset> _placePoints(SampledTemplate template, Size size) {
    final pts = template.points;
    if (pts.isEmpty) return const <Offset>[];

    if (_config.placement == PlacementMode.raw) {
      final offset = size.width / 2 - template.rasterSize.width / 2;
      return [for (final p in pts) Offset(p.dx + offset, p.dy)];
    }

    // Measure the shape's bounding box.
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final bbW = math.max(1e-3, maxX - minX);
    final bbH = math.max(1e-3, maxY - minY);
    final margin = _config.margin;
    final availW = math.max(1.0, size.width - 2 * margin);
    final availH = math.max(1.0, size.height - 2 * margin);
    // Uniform scale to fit, reduced by fillFraction.
    final scale =
        math.min(availW / bbW, availH / bbH) * _config.fillFraction;

    final scaledW = bbW * scale;
    final scaledH = bbH * scale;
    final freeX = math.max(0.0, availW - scaledW);
    final freeY = math.max(0.0, availH - scaledH);
    // Position the shape's center using the alignment within free space.
    final a = _config.alignment;
    final centerX = margin + scaledW / 2 + (a.x * 0.5 + 0.5) * freeX;
    final centerY = margin + scaledH / 2 + (a.y * 0.5 + 0.5) * freeY;
    final srcCx = minX + bbW / 2;
    final srcCy = minY + bbH / 2;

    return [
      for (final p in pts)
        Offset(
          centerX + (p.dx - srcCx) * scale,
          centerY + (p.dy - srcCy) * scale,
        ),
    ];
  }

  /// Ticker callback: accumulates real time and runs fixed sim steps.
  void _onTick(Duration elapsed) {
    if (!_hasLast) {
      _lastElapsed = elapsed;
      _hasLast = true;
      return;
    }
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt > 0.25) dt = 0.25; // Clamp after pauses to avoid huge catch-up.
    _accumulator += dt;

    var steps = 0;
    while (_accumulator >= _simDt && steps < _maxSubSteps) {
      _stepOnce();
      _accumulator -= _simDt;
      steps++;
    }
    if (steps == _maxSubSteps) _accumulator = 0.0;

    if (steps > 0) _repaint.tick();
  }

  /// Runs one simulation step, applying pending targets when due.
  void _stepOnce() {
    final pending = _pendingTargets;
    if (pending != null) {
      _pendingStepsLeft--;
      if (_pendingStepsLeft <= 0) {
        _engine.assignTargets(pending);
        _pendingTargets = null;
      }
    }
    _engine.step(
      maxSpeed: _config.maxSpeed,
      maxForce: _config.maxForce,
      arrivalRadius: _config.arrivalRadius,
      fleeRadius: _config.fleeRadius,
      dragging: _dragging,
      dragX: _dragX,
      dragY: _dragY,
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }
}

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show IconData;

import 'pixel_sampler.dart';

/// A source of particle positions (text, icon, image, or raw points).
/// Call [resolve] to turn it into a [SampledTemplate].
abstract class ParticleTarget {
  const ParticleTarget();

  /// Sample an image bundled as an asset.
  factory ParticleTarget.asset(
    String assetPath, {
    SampleMode mode,
    int stride,
    int threshold,
    double jitter,
  }) = _AssetTarget;

  /// Sample an already-decoded image.
  factory ParticleTarget.image(
    ui.Image image, {
    SampleMode mode,
    int stride,
    int threshold,
    double jitter,
  }) = _ImageTarget;

  /// Sample rendered text.
  factory ParticleTarget.text(
    String text, {
    TextStyle? style,
    int stride,
    int threshold,
    double jitter,
  }) = _TextTarget;

  /// Sample a rendered icon glyph.
  factory ParticleTarget.icon(
    IconData icon, {
    double size,
    int stride,
    int threshold,
    double jitter,
  }) = _IconTarget;

  /// Use an explicit list of points (no sampling).
  factory ParticleTarget.points(List<Offset> points, {Size? sourceSize}) =
      _PointsTarget;

  /// Delegate to a custom [PointSampler].
  factory ParticleTarget.sampler(PointSampler sampler) = _SamplerTarget;

  /// Produces the points that particles will move toward.
  Future<SampledTemplate> resolve();
}

/// Custom strategy for producing a [SampledTemplate].
abstract class PointSampler {
  Future<SampledTemplate> sample();
}

/// Loads an asset image, then samples its pixels.
class _AssetTarget extends ParticleTarget {
  _AssetTarget(
    this.assetPath, {
    this.mode = SampleMode.brightness,
    this.stride = 2,
    this.threshold = 20,
    this.jitter = 1.0,
  });
  final String assetPath;
  final SampleMode mode;
  final int stride;
  final int threshold;
  final double jitter;

  @override
  Future<SampledTemplate> resolve() async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final result = await sampleImage(
      frame.image,
      mode: mode,
      stride: stride,
      threshold: threshold,
      jitter: jitter,
    );
    frame.image.dispose();
    return result;
  }
}

/// Samples an in-memory image directly.
class _ImageTarget extends ParticleTarget {
  _ImageTarget(
    this.image, {
    this.mode = SampleMode.brightness,
    this.stride = 2,
    this.threshold = 20,
    this.jitter = 1.0,
  });
  final ui.Image image;
  final SampleMode mode;
  final int stride;
  final int threshold;
  final double jitter;

  @override
  Future<SampledTemplate> resolve() => sampleImage(image,
      mode: mode, stride: stride, threshold: threshold, jitter: jitter);
}

/// Renders text to an image, then samples its alpha channel.
class _TextTarget extends ParticleTarget {
  _TextTarget(
    this.text, {
    this.style,
    this.stride = 2,
    this.threshold = 24,
    this.jitter = 1.0,
  });
  final String text;
  final TextStyle? style;
  final int stride;
  final int threshold;
  final double jitter;

  @override
  Future<SampledTemplate> resolve() => sampleText(
        text,
        style: style,
        stride: stride,
        threshold: threshold,
        jitter: jitter,
      );
}

/// Renders an icon glyph to an image, then samples its alpha channel.
class _IconTarget extends ParticleTarget {
  _IconTarget(
    this.icon, {
    this.size = 220.0,
    this.stride = 2,
    this.threshold = 24,
    this.jitter = 1.0,
  });
  final IconData icon;
  final double size;
  final int stride;
  final int threshold;
  final double jitter;

  @override
  Future<SampledTemplate> resolve() => sampleIcon(
        icon,
        size: size,
        stride: stride,
        threshold: threshold,
        jitter: jitter,
      );
}

/// Wraps a caller-supplied point list; infers source size when omitted.
class _PointsTarget extends ParticleTarget {
  _PointsTarget(this.points, {this.sourceSize});
  final List<Offset> points;
  final Size? sourceSize;

  @override
  Future<SampledTemplate> resolve() async {
    var size = sourceSize;
    if (size == null) {
      var maxX = 1.0;
      var maxY = 1.0;
      for (final p in points) {
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      size = Size(maxX, maxY);
    }
    return SampledTemplate(points, size);
  }
}

/// Delegates resolution to a custom [PointSampler].
class _SamplerTarget extends ParticleTarget {
  _SamplerTarget(this.sampler);
  final PointSampler sampler;

  @override
  Future<SampledTemplate> resolve() => sampler.sample();
}

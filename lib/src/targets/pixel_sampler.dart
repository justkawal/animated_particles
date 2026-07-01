import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Which channel decides whether a pixel becomes a particle.
enum SampleMode {
  alpha,
  brightness,
}

/// Plain data passed to the scan, so it can run in a background isolate.
@immutable
class _SampleArgs {
  const _SampleArgs(
    this.bytes,
    this.width,
    this.height,
    this.stride,
    this.threshold,
    this.mode,
    this.jitter,
  );
  final Uint8List bytes;
  final int width;
  final int height;
  final int stride;
  final int threshold;
  final SampleMode mode;
  final double jitter;
}

/// Walks the RGBA pixels on a grid and emits a point for each one that
/// passes the threshold, optionally nudged by a deterministic jitter.
List<Offset> _scan(_SampleArgs a) {
  final bytes = a.bytes;
  final rowStride = a.width * 4;
  final pts = <Offset>[];
  final alpha = a.mode == SampleMode.alpha;
  final jitterAmp = a.stride * a.jitter;
  // Seeded RNG keeps jitter stable across runs.
  final rng = jitterAmp > 0 ? math.Random(0xC0FFEE) : null;
  for (var y = 0; y < a.height; y += a.stride) {
    final rowBase = y * rowStride;
    for (var x = 0; x < a.width; x += a.stride) {
      final i = rowBase + (x << 2);
      final int v = alpha
          ? bytes[i + 3]
          : (bytes[i] + bytes[i + 1] + bytes[i + 2]) ~/ 3;
      if (v > a.threshold) {
        if (rng != null) {
          pts.add(Offset(
            x + (rng.nextDouble() - 0.5) * jitterAmp,
            y + (rng.nextDouble() - 0.5) * jitterAmp,
          ));
        } else {
          pts.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
  }
  return pts;
}

/// Sampled points plus the size of the image they came from.
@immutable
class SampledTemplate {
  const SampledTemplate(this.points, this.rasterSize);
  final List<Offset> points;
  final Size rasterSize;

  bool get isEmpty => points.isEmpty;
  int get length => points.length;
}

/// Samples an image into points. Lower [stride] = denser; [threshold]
/// sets the cutoff; [jitter] adds randomness; the scan runs off the UI thread.
Future<SampledTemplate> sampleImage(
  ui.Image image, {
  SampleMode mode = SampleMode.brightness,
  int stride = 2,
  int threshold = 20,
  double jitter = 0.0,
}) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  if (data == null) {
    return SampledTemplate(
      const <Offset>[],
      Size(image.width.toDouble(), image.height.toDouble()),
    );
  }
  final args = _SampleArgs(
    data.buffer.asUint8List(),
    image.width,
    image.height,
    stride,
    threshold,
    mode,
    jitter,
  );
  final pts = await compute(_scan, args);
  return SampledTemplate(
    pts,
    Size(image.width.toDouble(), image.height.toDouble()),
  );
}

/// Rasterizes [text] to an image and samples its alpha channel.
Future<SampledTemplate> sampleText(
  String text, {
  TextStyle? style,
  int stride = 2,
  int threshold = 24,
  double jitter = 0.0,
}) async {
  // Force white so alpha matches the glyph coverage.
  final effectiveStyle = (style ?? const TextStyle())
      .copyWith(color: const Color(0xFFFFFFFF));
  final painter = TextPainter(
    text: TextSpan(text: text, style: effectiveStyle),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  final image = await _rasterize(
    painter.width.ceil(),
    painter.height.ceil(),
    (canvas) => painter.paint(canvas, Offset.zero),
  );
  final result = await sampleImage(
    image,
    mode: SampleMode.alpha,
    stride: stride,
    threshold: threshold,
    jitter: jitter,
  );
  image.dispose();
  return result;
}

/// Rasterizes an icon glyph to an image and samples its alpha channel.
Future<SampledTemplate> sampleIcon(
  IconData icon, {
  double size = 220.0,
  int stride = 2,
  int threshold = 24,
  double jitter = 0.0,
}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final image = await _rasterize(
    painter.width.ceil(),
    painter.height.ceil(),
    (canvas) => painter.paint(canvas, Offset.zero),
  );
  final result = await sampleImage(
    image,
    mode: SampleMode.alpha,
    stride: stride,
    threshold: threshold,
    jitter: jitter,
  );
  image.dispose();
  return result;
}

/// Draws [paint] onto a fresh image of the given size (min 1x1).
Future<ui.Image> _rasterize(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final w = width < 1 ? 1 : width;
  final h = height < 1 ? 1 : height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}

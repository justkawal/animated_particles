# animated_particles

[![pub package](https://img.shields.io/pub/v/animated_particles.svg)](https://pub.dev/packages/animated_particles)
[![platform](https://img.shields.io/badge/platform-Flutter-02569B?logo=flutter)](https://flutter.dev)

A fast, smooth **steering-behavior particle field** for Flutter. Particles are
sampled from text, icons, or images, then **arrive** into the shape, **morph**
between shapes, **flee** from your touch, and **escape** off-screen - all driven
by one `drawRawPoints` call and a tight structure-of-arrays engine.

[<img src="https://raw.githubusercontent.com/justkawal/animated_particles/main/doc/demo.gif" width="300" alt="animated_particles demo — particles forming and morphing between text, icons and shapes">](https://github.com/justkawal/animated_particles/blob/d55e47e5dcd8b8d071fa151e62762dcbabe0f7ba/doc/demo.mp4)

> ▶️ The GIF is a 2× sped-up preview — **[watch the full-quality recording (mp4)](https://github.com/justkawal/animated_particles/blob/d55e47e5dcd8b8d071fa151e62762dcbabe0f7ba/doc/demo.mp4)**.

---

## Features

- 🅰️ **Sample anything** - build a target from `text`, an `icon`, an `asset`
  image, a decoded `ui.Image`, an explicit list of points, or a custom sampler.
- 🔀 **Morph between shapes** - particles flee to a chosen edge, then reform
  into the next target after a short delay.
- ⚡ **Built for 60 fps** - a fixed 30 Hz simulation, flat `Float32List` arrays,
  off-thread image sampling, and a single `drawRawPoints` per frame inside a
  `RepaintBoundary`.
- 🎛️ **Tunable** - speed, steering force, arrival/flee radii, particle size &
  shape, fill, alignment, margin, and more.
- 📦 **Pure Dart/Flutter** - no native code; runs on iOS, Android, macOS,
  Windows, Linux, and Web.

## Install

Add it to your `pubspec.yaml`:

```yaml
dependencies:
  animated_particles: ^0.1.0
```

…or from the command line:

```sh
flutter pub add animated_particles
```

Then import it:

```dart
import 'package:animated_particles/animated_particles.dart';
```

## Quick start

Create a `ParticleFieldController`, drop a `ParticleField` into your tree,
register some targets, and call `changeTarget` once the field has a size.

```dart
import 'package:flutter/material.dart';
import 'package:animated_particles/animated_particles.dart';

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  late final ParticleFieldController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ParticleFieldController(
      config: const ParticleFieldConfig(
        color: Color(0xFFEAF2FF),
        particleSize: 1.6,
        shape: ParticleShape.circle,
        antiAlias: true,
      ),
    );
    _load();
  }

  Future<void> _load() async {
    // Resolving samples text/icons off the UI thread.
    await _controller.addTargets({
      'hello': ParticleTarget.text(
        'Hello', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w800),
      ),
      'heart': ParticleTarget.icon(Icons.favorite, size: 240),
    });
    // changeTarget only forms a shape once the field has been laid out
    // (has a non-zero size), so wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.changeTarget('hello');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: ParticleField(
        controller: _controller,
        backgroundColor: const Color(0xFF07080B),
      ),
      floatingActionButton: FloatingActionButton(
        // Tap to morph: flee to the escape edge, then reform.
        onPressed: () => _controller.changeTarget('heart'),
        child: const Icon(Icons.favorite),
      ),
    );
  }
}
```

> **Why `addPostFrameCallback`?** `changeTarget` places points in the field's
> coordinate space, which only exists after layout. Calling it before the field
> has a size sets the active target but won't move particles until a size is
> known. Calls triggered by user input (a button tap) are always safe.

## Targets

A `ParticleTarget` is a recipe for a cloud of points. Build one with a factory,
register it under a key, then switch to it with `changeTarget`. Sampling walks
the source on a grid: smaller **`stride`** = denser (more particles), **`threshold`**
is the alpha/brightness cutoff, and **`jitter`** nudges points off the grid so
the result doesn't look mechanical.

| Factory | Builds points from | Key options (defaults) |
| --- | --- | --- |
| `ParticleTarget.text(text, …)` | rendered text (alpha) | `style`, `stride: 2`, `threshold: 24`, `jitter: 1.0` |
| `ParticleTarget.icon(icon, …)` | a rendered icon glyph (alpha) | `size: 220`, `stride: 2`, `threshold: 24`, `jitter: 1.0` |
| `ParticleTarget.asset(path, …)` | a bundled asset image | `mode: brightness`, `stride: 2`, `threshold: 20`, `jitter: 1.0` |
| `ParticleTarget.image(uiImage, …)` | an already-decoded `ui.Image` | `mode`, `stride`, `threshold`, `jitter` |
| `ParticleTarget.points(points, …)` | an explicit `List<Offset>` | `sourceSize` |
| `ParticleTarget.sampler(sampler)` | your own `PointSampler` | - |

```dart
await controller.addTargets({
  'logo':  ParticleTarget.asset('assets/logo.png', stride: 3),
  'flutter': ParticleTarget.text('Flutter',
      style: const TextStyle(fontSize: 130, fontWeight: FontWeight.w800)),
  'dash':  ParticleTarget.icon(Icons.flutter_dash, size: 260),
  'ring':  ParticleTarget.points(myCirclePoints),
});

controller.changeTarget('flutter'); // morph!
```

`SampleMode.alpha` keys off the alpha channel (used automatically for text &
icons); `SampleMode.brightness` keys off pixel luminance (the default for
images).

## Configuration

Everything about motion and appearance lives in the immutable
`ParticleFieldConfig`. Pass one to the controller, or swap it live with
`controller.config = controller.config.copyWith(...)`.

| Field | Default | Description |
| --- | --- | --- |
| `maxSpeed` | `20.0` | Top speed, in pixels per step. |
| `maxForce` | `3.0` | Max steering force per step (turn sharpness). |
| `arrivalRadius` | `100.0` | Distance at which particles start easing in. |
| `fleeRadius` | `40.0` | Particles within this distance of the touch are pushed away. |
| `escapePosition` | `EscapePosition.bottom` | Edge particles flee to before reforming. |
| `reformDelay` | `100 ms` | Pause between escaping and heading to the new target. |
| `color` | `0xFFFFFFFF` | Particle color. |
| `particleSize` | `2.0` | Particle diameter / side length, in pixels. |
| `shape` | `ParticleShape.square` | `square` or `circle`. |
| `antiAlias` | `false` | Smoother edges, slightly slower. |
| `particleCount` | `null` | Fixed count; when `null`, follows the largest target. |
| `placement` | `PlacementMode.fit` | `fit` (scale to field) or `raw` (use sampled coords). |
| `fillFraction` | `0.78` | Fraction of the available space the shape fills (0–1). |
| `alignment` | `Alignment(0, -0.35)` | Where the shape sits within the field. |
| `margin` | `16.0` | Empty space kept around the shape, in pixels. |

```dart
// Live-tweak the flee direction, then preview it immediately.
controller.config = controller.config.copyWith(
  escapePosition: EscapePosition.right,
);
controller.escape();
```

## Controller API

`ParticleFieldController` extends `ChangeNotifier`.

**Targets & morphing**

| Member | What it does |
| --- | --- |
| `addTarget(key, target)` → `Future` | Resolve & register a single target. |
| `addTargets(map)` → `Future` | Resolve & register several at once. |
| `removeTarget(key)` | Unregister a target. |
| `changeTarget(key)` | Flee to the escape edge, then reform into `key`. Throws if `key` isn't registered. |
| `escape()` | Send particles fleeing to the escape edge (cancels a pending reform). |
| `setDragPoint(offset?)` | Set / clear the point particles flee from. |
| `start()` / `stop()` | Start / stop the simulation ticker. |

**State (getters)**

| Member | Returns |
| --- | --- |
| `config` (get/set) | The current `ParticleFieldConfig`. Setting it re-spawns particles if the count changed. |
| `particleCount` | Number of live particles. |
| `activeKey` | Key of the current target (or `null`). |
| `keys` | Names of all registered targets. |
| `isRunning` | Whether the ticker is active. |
| `repaint` | A `Listenable` that fires once per simulated frame. |

The controller notifies its `ChangeNotifier` listeners when targets or the
config change - handy for driving a live particle-count readout:

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Text('${controller.particleCount} particles'),
);
```

Call `controller.dispose()` when you're done.

## The widget

```dart
ParticleField(
  controller: controller,
  handleDrag: true,
  backgroundColor: const Color(0xFF07080B),
)
```

`ParticleField` reports its size to the controller and - when `handleDrag` is
`true` - forwards pan gestures so particles flee from your finger within
`fleeRadius`. Set `handleDrag: false` if the field sits behind other interactive
UI (as the example does, with its own control deck on top).

## How it works

1. **Sample** - text, icons, and images are rasterized to an offscreen image;
   pixels are scanned on a `stride` grid and those above `threshold` become
   target points. The scan runs in a background isolate via `compute`, so big
   images never jank the UI thread.
2. **Place** - the sampled cloud is scaled to fit the field (`fillFraction`,
   `margin`, `alignment`), or used `raw`.
3. **Simulate** - a fixed **30 Hz** timestep (with accumulator + up to 5
   catch-up sub-steps) advances every particle using Reynolds-style *arrive*
   steering toward its target, plus a *flee* force from the touch point.
4. **Render** - all particles are drawn in a **single `canvas.drawRawPoints`**
   call. Particle size maps to stroke width and `circle` to a round stroke cap;
   a `RepaintBoundary` keeps the rest of your tree off the repaint path.

State lives in flat `Float32List` arrays (structure-of-arrays) for
cache-friendly stepping, which is what keeps large fields smooth.

**Performance tips**

- Fewer particles = faster: raise `stride`, or pin a `particleCount`.
- Leave `antiAlias` off for the largest fields; `square` is marginally cheaper
  than `circle`.
- One `ParticleField` already isolates its own repaints - keep heavy widgets
  out from under it.

## Example

A full, polished demo - a gallery of text/icon targets, escape-edge control, and
a live particle counter - lives in [`example/`](example/lib/main.dart). Run it
with:

```sh
cd example
flutter run
```

## License

MIT © Kawaljeet Singh — see the [LICENSE](LICENSE) file.

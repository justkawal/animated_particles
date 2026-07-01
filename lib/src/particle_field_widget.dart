import 'package:flutter/widgets.dart';

import 'particle_field_controller.dart';
import 'rendering/particle_layer.dart';

/// Widget that displays the particles driven by a [ParticleFieldController].
/// Reports its size to the controller and forwards drag gestures to it.
class ParticleField extends StatefulWidget {
  const ParticleField({
    super.key,
    required this.controller,
    this.handleDrag = true,
    this.backgroundColor,
  });

  /// The controller running the simulation.
  final ParticleFieldController controller;

  /// Whether drags repel nearby particles.
  final bool handleDrag;

  /// Optional fill color painted behind the particles.
  final Color? backgroundColor;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Provide the vsync the controller's ticker needs.
    widget.controller.attach(this);
  }

  // Feed pointer positions to the controller's flee behavior.
  void _onPanStart(DragStartDetails d) =>
      widget.controller.setDragPoint(d.localPosition);
  void _onPanUpdate(DragUpdateDetails d) =>
      widget.controller.setDragPoint(d.localPosition);
  void _onPanEnd(DragEndDetails d) => widget.controller.setDragPoint(null);
  void _onPanCancel() => widget.controller.setDragPoint(null);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.setSize(constraints.biggest);

        // Rebuilds only when config changes; repaints are driven separately.
        Widget field = ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final cfg = widget.controller.config;
            return ParticleLayer(
              engine: widget.controller.engine,
              repaint: widget.controller.repaint,
              color: cfg.color,
              particleSize: cfg.particleSize,
              shape: cfg.shape,
              antiAlias: cfg.antiAlias,
            );
          },
        );

        // Isolate frequent particle repaints from the rest of the tree.
        field = RepaintBoundary(child: field);

        if (widget.backgroundColor != null) {
          field = ColoredBox(color: widget.backgroundColor!, child: field);
        }

        if (widget.handleDrag) {
          field = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: field,
          );
        }

        return field;
      },
    );
  }
}

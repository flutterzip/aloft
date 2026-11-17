import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../config/palette.dart';
import 'aloft_mark.dart';
import 'plane.dart';

/// The app's loader: a plane circling the logo on a tilted orbit, passing
/// behind the window and in front of it, with its trail thinning out behind.
///
/// One controller drives the painter; nothing rebuilds. It stands still
/// under reduce motion.
class FlightLoader extends StatefulWidget {
  const FlightLoader({super.key, this.size = 132, this.frame, this.trail});

  final double size;

  /// The logo's frame and the plane's colour. Default to the page's ink.
  final Color? frame;
  final Color? trail;

  @override
  State<FlightLoader> createState() => _FlightLoaderState();
}

class _FlightLoaderState extends State<FlightLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_orbit.isAnimating) _orbit.repeat();
    } else {
      _orbit.value = .12;
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbitPainter(
            orbit: _orbit,
            palette: p,
            frame: widget.frame ?? p.ink,
            trail: widget.trail ?? p.accent,
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.orbit,
    required this.palette,
    required this.frame,
    required this.trail,
  }) : super(repaint: orbit);

  final Animation<double> orbit;
  final Palette palette;
  final Color frame;
  final Color trail;

  static const _tilt = -.32;

  Offset _at(Size size, double angle) {
    final rx = size.width * .46;
    final ry = rx * .34;
    final x = math.cos(angle) * rx;
    final y = math.sin(angle) * ry;
    return size.center(Offset.zero) +
        Offset(
          x * math.cos(_tilt) - y * math.sin(_tilt),
          x * math.sin(_tilt) + y * math.cos(_tilt),
        );
  }

  void _plane(Canvas canvas, Size size, double angle, {required bool front}) {
    // The trail: short strokes behind the plane, thinner and fainter the
    // older they are. Only the half on this side of the logo is drawn.
    const steps = 26;
    const sweep = 2.3;
    for (var i = steps; i >= 1; i--) {
      final a0 = angle - sweep * i / steps;
      final a1 = angle - sweep * (i - 1) / steps;
      if ((math.sin(a0) > 0) != front) continue;
      final age = i / steps;
      canvas.drawLine(
        _at(size, a0),
        _at(size, a1),
        Paint()
          ..color = trail.withValues(alpha: (1 - age) * .9)
          ..strokeWidth = 3.2 * (1 - age) + .6
          ..strokeCap = StrokeCap.round,
      );
    }
    if ((math.sin(angle) > 0) != front) return;
    final here = _at(size, angle);
    final ahead = _at(size, angle + .02);
    final depth = math.sin(angle);
    paintPlane(
      canvas,
      at: here,
      angle: math.atan2(ahead.dy - here.dy, ahead.dx - here.dx),
      length: size.width * (.19 + .05 * depth),
      color: frame,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final angle = orbit.value * 2 * math.pi;
    _plane(canvas, size, angle, front: false);
    final mark = size.width * .5;
    canvas.save();
    canvas.translate((size.width - mark) / 2, (size.height - mark) / 2);
    MarkPainter(
      palette: palette,
      frame: frame,
    ).paint(canvas, Size.square(mark));
    canvas.restore();
    _plane(canvas, size, angle, front: true);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.palette != palette || old.frame != frame || old.trail != trail;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'plane.dart';

/// A flight path between two points: an arc bowed upwards, dashed where the
/// plane has yet to fly and solid where it has been, with the plane on it
/// pointing along the curve.
///
/// [progress] is listened to by the painter, so an animation moves the
/// plane without rebuilding anything. For a still arc pass
/// `AlwaysStoppedAnimation(x)`.
class RouteArc extends StatelessWidget {
  const RouteArc({
    super.key,
    required this.progress,
    required this.line,
    required this.flown,
    required this.plane,
    this.bow = .7,
    this.planeSize = 18,
    this.stroke = 1.6,
    this.dots = true,
    this.stop = false,
    this.shadow,
  });

  final Animation<double> progress;

  /// The path still to fly, the path flown and the plane.
  final Color line;
  final Color flown;
  final Color plane;

  /// How high the arc rises, as a fraction of the box's height.
  final double bow;
  final double planeSize;
  final double stroke;

  /// Whether to draw the two end points.
  final bool dots;

  /// Marks the middle of the arc as a stop.
  final bool stop;
  final Color? shadow;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.infinite, painter: _ArcPainter(this)),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.w) : super(repaint: w.progress);

  final RouteArc w;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = w.planeSize * .5;
    final a = Offset(pad, size.height - pad * .7);
    final b = Offset(size.width - pad, size.height - pad * .7);
    final c = Offset(size.width / 2, a.dy - (size.height - pad) * w.bow * 2);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    final metric = path.computeMetrics().first;
    final t = w.progress.value.clamp(0.0, 1.0);
    final at = metric.length * t;

    final dash = Paint()
      ..color = w.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = w.stroke
      ..strokeCap = StrokeCap.round;
    const on = 4.0, off = 5.0;
    for (var d = at + off; d < metric.length; d += on + off) {
      canvas.drawPath(
        metric.extractPath(d, math.min(d + on, metric.length)),
        dash,
      );
    }
    if (t > 0) {
      canvas.drawPath(
        metric.extractPath(0, at),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w.stroke + .4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(a, b, [
            w.flown.withValues(alpha: .25),
            w.flown,
          ]),
      );
    }
    if (w.dots) {
      canvas.drawCircle(a, 3.2, Paint()..color = t > 0 ? w.flown : w.line);
      canvas.drawCircle(b, 3.2, Paint()..color = t >= 1 ? w.flown : w.line);
    }
    if (w.stop) {
      final mid = metric.getTangentForOffset(metric.length / 2)!.position;
      canvas.drawCircle(mid, 3.6, Paint()..color = w.line);
      canvas.drawCircle(
        mid,
        3.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = t > .5 ? w.flown : w.line,
      );
    }
    final tangent = metric.getTangentForOffset(at)!;
    paintPlane(
      canvas,
      at: tangent.position,
      angle: -tangent.angle,
      length: w.planeSize,
      color: w.plane,
      shadow: w.shadow,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.w.line != w.line ||
      old.w.flown != w.flown ||
      old.w.plane != w.plane ||
      old.w.progress != w.progress ||
      old.w.stop != w.stop;
}

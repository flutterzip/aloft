import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The airliner seen from above, nose to the right, one unit long and
/// centred on the origin. Every plane in the app is this one path: on a
/// route arc, in the sky, in the loader and on the tab bar.
final Path planePath = _buildPlane();

Path _buildPlane() {
  final body = Path()
    ..moveTo(.5, 0)
    ..cubicTo(.46, -.05, .36, -.058, .26, -.058)
    ..lineTo(-.4, -.05)
    ..cubicTo(-.47, -.045, -.5, -.02, -.5, 0)
    ..cubicTo(-.5, .02, -.47, .045, -.4, .05)
    ..lineTo(.26, .058)
    ..cubicTo(.36, .058, .46, .05, .5, 0)
    ..close();
  Path wing(double s) => Path()
    ..moveTo(.12, .05 * s)
    ..lineTo(-.13, .47 * s)
    ..lineTo(-.22, .47 * s)
    ..lineTo(-.1, .05 * s)
    ..close();
  Path tail(double s) => Path()
    ..moveTo(-.33, .04 * s)
    ..lineTo(-.45, .2 * s)
    ..lineTo(-.5, .2 * s)
    ..lineTo(-.45, .04 * s)
    ..close();
  return Path()
    ..addPath(body, Offset.zero)
    ..addPath(wing(1), Offset.zero)
    ..addPath(wing(-1), Offset.zero)
    ..addPath(tail(1), Offset.zero)
    ..addPath(tail(-1), Offset.zero);
}

/// Draws the plane [length] long at [at], pointing along [angle] (radians,
/// 0 is to the right).
void paintPlane(
  Canvas canvas, {
  required Offset at,
  required double angle,
  required double length,
  required Color color,
  Color? shadow,
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  canvas.scale(length);
  if (shadow != null) {
    canvas.drawPath(
      planePath.shift(const Offset(-.04, .12)),
      Paint()..color = shadow,
    );
  }
  canvas.drawPath(planePath, Paint()..color = color);
  canvas.restore();
}

/// The plane as a widget, for buttons, labels and empty states.
class PlaneIcon extends StatelessWidget {
  const PlaneIcon({
    super.key,
    required this.color,
    this.size = 20,
    this.angle = 0,
  });

  final Color color;
  final double size;

  /// Radians; 0 points right, negative climbs.
  final double angle;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PlaneIconPainter(color, angle),
  );
}

class _PlaneIconPainter extends CustomPainter {
  const _PlaneIconPainter(this.color, this.angle);

  final Color color;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) => paintPlane(
    canvas,
    at: size.center(Offset.zero),
    angle: angle,
    length: math.min(size.width, size.height),
    color: color,
  );

  @override
  bool shouldRepaint(_PlaneIconPainter old) =>
      old.color != color || old.angle != angle;
}

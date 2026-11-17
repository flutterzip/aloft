import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/when.dart';

/// A card with a half-round bite out of each side at [notchAt] from the
/// top, where a ticket tears. Used as a `ShapeBorder`, so ink, clipping and
/// shadows all follow it.
class TicketShape extends ShapeBorder {
  const TicketShape({
    required this.notchAt,
    this.radius = 22,
    this.notch = 9,
    this.side = BorderSide.none,
  });

  final double notchAt;
  final double radius;
  final double notch;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Path _path(Rect r) {
    final y = r.top + notchAt.clamp(radius + notch, r.height - radius - notch);
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    final bites = Path()
      ..addOval(Rect.fromCircle(center: Offset(r.left, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(r.right, y), radius: notch));
    return Path.combine(PathOperation.difference, body, bites);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => TicketShape(
    notchAt: notchAt * t,
    radius: radius * t,
    notch: notch * t,
    side: side.scale(t),
  );
}

/// The dotted tear line across a ticket.
class Perforation extends StatelessWidget {
  const Perforation({super.key, this.color, this.inset = 16});

  final Color? color;
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: inset),
    child: CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashPainter(color ?? context.palette.line),
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 1), Offset(x + 3, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A barcode drawn from [data]: the same reference always gives the same
/// bars. Decorative; a real pass would encode its payload with a barcode
/// package here.
class Barcode extends StatelessWidget {
  const Barcode({
    super.key,
    required this.data,
    required this.color,
    this.height = 44,
  });

  final String data;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Barcode',
    child: CustomPaint(
      size: Size(double.infinity, height),
      painter: _BarcodePainter(data, color),
    ),
  );
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.data, this.color);

  final String data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final h = stableHash('$data$i');
      final bar = 1.0 + h % 3;
      final gap = 1.0 + (h ~/ 3) % 3;
      if (x + bar > size.width) break;
      canvas.drawRect(Rect.fromLTWH(x, 0, bar, size.height), paint);
      x += bar + gap;
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) =>
      old.data != data || old.color != color;
}

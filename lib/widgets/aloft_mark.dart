import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../config/app_theme.dart';
import '../config/palette.dart';

/// The Aloft mark: an aircraft window with its shade a little lowered, and
/// through it the sun coming up over a bank of cloud.
///
/// It is drawn, not an image, so its parts can move: [draw] traces the
/// frame, [lift] raises the shade (0 is shut, 1 is its resting place) and
/// [rise] brings the sun up from behind the cloud. The splash plays all
/// three; everywhere else they rest at 1.
///
/// The geometry is on a 100 x 100 canvas and is shared with the app icon,
/// which `test/tool/render_brand_test.dart` renders from this painter.
class AloftMark extends StatelessWidget {
  const AloftMark({
    super.key,
    this.size = 56,
    this.draw = 1,
    this.lift = 1,
    this.rise = 1,
    this.frame,
  });

  final double size;
  final double draw;
  final double lift;
  final double rise;

  /// The window frame's colour. Defaults to the ink of the page.
  final Color? frame;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: MarkPainter(
        palette: p,
        frame: frame ?? p.ink,
        draw: draw,
        lift: lift,
        rise: rise,
      ),
    );
  }
}

class MarkPainter extends CustomPainter {
  const MarkPainter({
    required this.palette,
    required this.frame,
    this.draw = 1,
    this.lift = 1,
    this.rise = 1,
    this.paneOpacity = 1,
  });

  final Palette palette;
  final Color frame;
  final double draw;
  final double lift;
  final double rise;

  /// The splash fades the view out of the window as the camera goes
  /// through it.
  final double paneOpacity;

  /// The glass, on the 100 x 100 canvas. The splash opens exactly this
  /// shape onto the first screen.
  static const pane = Rect.fromLTRB(27, 13, 73, 87);
  static const paneRadius = 21.0;
  static const _mid = Rect.fromLTRB(23.5, 9.5, 76.5, 90.5);
  static const _midRadius = 24.5;
  static const _thickness = 7.0;

  /// Where the shade's lower edge rests when the window is open.
  static const _shadeRest = 25.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final glass = RRect.fromRectAndRadius(
      pane,
      const Radius.circular(paneRadius),
    );

    if (paneOpacity > 0 && lift > 0) {
      canvas.save();
      canvas.clipRRect(glass);
      if (paneOpacity < 1) {
        canvas.saveLayer(
          pane,
          // Only the alpha of this paint matters.
          Paint()..color = palette.sky.first.withValues(alpha: paneOpacity),
        );
      }
      _view(canvas);
      if (paneOpacity < 1) canvas.restore();
      canvas.restore();
    }

    // The shade: shut at lift 0, resting a little lowered at 1.
    final edge = ui.lerpDouble(pane.bottom, _shadeRest, lift)!;
    canvas.save();
    canvas.clipRRect(glass);
    final shade = Color.lerp(frame, palette.sky[1], .16)!;
    canvas.drawRect(
      Rect.fromLTRB(pane.left, pane.top, pane.right, edge),
      Paint()..color = shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(pane.left, edge - 2.2, pane.right, edge),
      Paint()..color = Color.lerp(frame, palette.sky[0], .38)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(50, edge - 5.4), width: 11, height: 2),
        const Radius.circular(1),
      ),
      Paint()..color = Color.lerp(frame, palette.sky[0], .38)!,
    );
    canvas.restore();

    // The frame, traced from the top centre when it is being drawn.
    final ring = Path()
      ..addRRect(
        RRect.fromRectAndRadius(_mid, const Radius.circular(_midRadius)),
      );
    final stroke = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = _thickness
      ..strokeCap = StrokeCap.round;
    if (draw >= 1) {
      canvas.drawPath(ring, stroke);
    } else if (draw > 0) {
      final metric = ring.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * draw), stroke);
    }
    canvas.restore();
  }

  void _view(Canvas canvas) {
    final p = palette;
    canvas.drawRect(
      pane,
      Paint()
        ..shader = ui.Gradient.linear(
          pane.topCenter,
          pane.bottomCenter,
          [p.sky[0], p.sky[2], Color.lerp(p.sky[2], p.cloud, .28 * rise)!],
          const [0, .7, 1],
        ),
    );
    final sun = Offset(56, ui.lerpDouble(80, 56, rise)!);
    canvas.drawCircle(
      sun,
      30,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(sun, 30, [
          p.sun.withValues(alpha: .5 * rise),
          p.sun.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(sun, 10.5, Paint()..color = p.sun);
    final cloud = Paint()..color = p.cloud;
    for (final (x, y, r) in const [
      (31.0, 76.0, 9.0),
      (43.0, 72.0, 10.5),
      (57.0, 77.0, 9.5),
      (69.0, 73.0, 9.0),
    ]) {
      canvas.drawCircle(Offset(x, y), r, cloud);
    }
    canvas.drawRect(
      Rect.fromLTRB(pane.left, 76, pane.right, pane.bottom),
      cloud,
    );
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.draw != draw ||
      old.lift != lift ||
      old.rise != rise ||
      old.paneOpacity != paneOpacity ||
      old.frame != frame ||
      old.palette != palette;
}

/// The name, set in the house face. [settle] (0 to 1) brings the letters up
/// out of a clipped baseline one after another.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.settle = 1, this.color});

  final double size;
  final double settle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTheme.font,
      fontSize: size,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -size * .035,
      color: color ?? context.palette.ink,
    );
    const name = AppBrand.name;
    if (settle >= 1) return Text(name, style: style);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: ClipRect(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < name.length; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  size *
                      1.2 *
                      (1 -
                          Curves.easeOutCubic.transform(
                            ((settle * (1 + name.length * .12) - i * .12))
                                .clamp(0.0, 1.0),
                          )),
                ),
                child: Text(name[i], style: style),
              ),
          ],
        ),
      ),
    );
  }
}

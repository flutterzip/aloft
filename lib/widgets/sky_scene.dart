import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../config/palette.dart';
import 'plane.dart';

/// The sky above the weather: the app's dusk gradient, the sun's glow low
/// on one side, two banks of cloud drifting at different speeds and, now
/// and then, a plane climbing across with its trail fading behind it.
///
/// It is behind the sign-in form and every header. One slow controller
/// drives a painter directly (nothing rebuilds), it sits in its own repaint
/// boundary, and it stands still under reduce motion or when its tickers
/// are muted because the tab is hidden.
class SkyScene extends StatefulWidget {
  const SkyScene({
    super.key,
    this.sun = const Alignment(.72, .9),
    this.plane = true,
    this.child,
  });

  /// Where the sun's glow sits.
  final Alignment sun;
  final bool plane;
  final Widget? child;

  @override
  State<SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<SkyScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: Motion.skyLoop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_loop.isAnimating) {
        // Every sky in the app is at the same point of the same loop, so
        // one can hand over to another without the clouds jumping.
        final period = Motion.skyLoop.inMilliseconds;
        _loop.value = (DateTime.now().millisecondsSinceEpoch % period) / period;
        _loop.repeat();
      }
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: SkyPainter(
        palette: context.palette,
        loop: _loop,
        sun: widget.sun,
        plane: widget.plane,
      ),
      child: widget.child,
    ),
  );
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.palette,
    required this.loop,
    required this.sun,
    required this.plane,
  }) : super(repaint: loop);

  final Palette palette;
  final Animation<double> loop;
  final Alignment sun;
  final bool plane;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final rect = Offset.zero & size;
    final t = loop.value;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          p.sky,
          const [0, .55, 1],
        ),
    );
    final glowAt = sun.alongSize(size);
    final glowR = size.width * .75;
    canvas.drawCircle(
      glowAt,
      glowR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          glowAt,
          glowR,
          [
            p.sun.withValues(alpha: .38),
            p.sun.withValues(alpha: .09),
            p.sun.withValues(alpha: 0),
          ],
          const [0, .45, 1],
        ),
    );

    // The far bank drifts once per loop, the near one twice.
    _bank(canvas, size, drift: t, y: .5, scale: .8, alpha: .06, seed: 3);
    if (plane) _plane(canvas, size, t);
    _bank(canvas, size, drift: t * 2, y: .84, scale: 1.25, alpha: .1, seed: 7);
    canvas.restore();
  }

  void _bank(
    Canvas canvas,
    Size size, {
    required double drift,
    required double y,
    required double scale,
    required double alpha,
    required int seed,
  }) {
    final paint = Paint()..color = palette.cloud.withValues(alpha: alpha);
    const count = 3;
    final span = size.width * 1.5;
    for (var i = 0; i < count; i++) {
      final lane = (i / count + drift + seed * .137) % 1;
      final x = lane * span - size.width * .25;
      final cy = size.height * (y + .09 * math.sin(i * 2.4 + seed));
      final w = 120.0 * scale * (1 + .3 * math.cos(i * 1.7 + seed));
      canvas.drawPath(_cloud(Offset(x, cy), w), paint);
    }
  }

  static Path _cloud(Offset c, double w) {
    final h = w * .22;
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w, height: h),
          Radius.circular(h / 2),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: c + Offset(-w * .16, -h * .45),
          radius: w * .15,
        ),
      )
      ..addOval(
        Rect.fromCircle(center: c + Offset(w * .1, -h * .7), radius: w * .2),
      );
  }

  /// The plane crosses three times a loop and is out of frame in between.
  void _plane(Canvas canvas, Size size, double t) {
    final leg = (t * 3) % 1;
    if (leg > .5) return;
    final f = leg / .5;
    final from = Offset(-size.width * .2, size.height * .66);
    final to = Offset(size.width * 1.2, size.height * .2);
    final at = Offset.lerp(from, to, f)!;
    final dir = to - from;
    final angle = math.atan2(dir.dy, dir.dx);
    final unit = dir / dir.distance;
    final tail = at - unit * 110;
    canvas.drawLine(
      tail,
      at - unit * 9,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, at, [
          palette.onSky.withValues(alpha: 0),
          palette.onSky.withValues(alpha: .5),
        ]),
    );
    paintPlane(
      canvas,
      at: at,
      angle: angle,
      length: 20,
      color: palette.onSky.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.palette != palette || old.sun != sun || old.plane != plane;
}

/// The sky with a rounded lower edge, as a page header. [child] is laid out
/// inside the safe area.
class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key, required this.height, this.child, this.sun});

  final double height;
  final Widget? child;
  final Alignment? sun;

  static const radius = 30.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height + top,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(radius),
        ),
        child: SkyScene(
          sun: sun ?? const Alignment(.72, .9),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: context.palette.onSky),
              child: child ?? const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/motion.dart';
import '../../config/palette.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/aloft_mark.dart';

/// `intro`: the splash plays over a blank page. `warming`: the first screen
/// is mounted underneath, hidden, so its heavy first build happens while the
/// logo holds; its entrance waits. `leaving`: the camera goes through the
/// window and the first screen's entrance plays. `done`: the splash is gone.
enum SplashPhase { intro, warming, leaving, done }

final splashPhaseProvider = StateProvider<SplashPhase>(
  (_) => AppTiming.scale == 0 ? SplashPhase.done : SplashPhase.intro,
);

/// The opening shot. On a night sky the window's frame is traced, its shade
/// lifts, the sun comes up over the cloud inside it and the name rises
/// letter by letter. Then the camera flies through the glass: the window
/// grows past the edges of the phone and what was the view through it is
/// the first screen.
///
/// One controller in, one out, both read straight by a painter. It leaves
/// only when the intro has played *and* the data has loaded, so it never
/// opens onto a half-loaded screen. With reduced motion it is a still logo
/// and a fade.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key});

  /// The logo's size on the splash, and how far up the screen it sits.
  static const markSize = 148.0;
  static const markAt = .4;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _out;
  bool _hapticDone = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: AppTiming.splashIn);
    _out = AnimationController(vsync: this, duration: AppTiming.splashOut);
    _run();
  }

  Future<void> _run() async {
    // Through the repositories: with a backend these are the first network
    // calls, and the splash covers them.
    final ready = Future.wait<Object?>([
      ref.read(worldProvider.future),
      ref.read(popularRoutesProvider.future),
      ref.read(tripsProvider.future),
    ]);
    _in.addListener(_haptic);
    await _in.forward();
    try {
      await ready;
    } catch (_) {
      // The first screen shows the failure and offers a retry.
    }
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.warming;
    await AppTiming.wait(AppTiming.splashHold);
    for (var i = 0; i < 2; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.leaving;
    await _out.forward();
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.done;
  }

  void _haptic() {
    if (!_hapticDone && _in.value > .5) {
      _hapticDone = true;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  static double _slice(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduced = Motion.reduced(context);
    final size = MediaQuery.sizeOf(context);
    final centre = Offset(size.width / 2, size.height * SplashOverlay.markAt);
    // A transparent Material, not a bare box: the splash sits above the
    // Navigator, where no Scaffold gives text a default style.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _out,
        builder: (context, child) => IgnorePointer(
          ignoring: _out.value > .5,
          child: Opacity(
            opacity: reduced
                ? 1 - Curves.easeInCubic.transform(_out.value)
                : 1 - _slice(_out.value, .86, 1),
            child: child,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _SplashPainter(
                  intro: _in,
                  outro: _out,
                  palette: p,
                  centre: centre,
                  reduced: reduced,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: centre.dy + SplashOverlay.markSize / 2 + 22,
              child: AnimatedBuilder(
                animation: Listenable.merge([_in, _out]),
                builder: (context, _) {
                  final t = reduced ? 1.0 : _in.value;
                  final gone = reduced
                      ? 0.0
                      : Curves.easeIn.transform(_slice(_out.value, 0, .3));
                  final tagline = Curves.easeOut.transform(_slice(t, .78, 1));
                  return Opacity(
                    opacity: 1 - gone,
                    child: Transform.translate(
                      offset: Offset(0, 46 * gone),
                      child: Column(
                        children: [
                          Wordmark(
                            size: 40,
                            color: p.onSky,
                            settle: _slice(t, .46, .86),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: tagline,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - tagline)),
                              child: Text(
                                AppBrand.tagline,
                                style: context.body.copyWith(
                                  color: p.onSkyMuted,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.intro,
    required this.outro,
    required this.palette,
    required this.centre,
    required this.reduced,
  }) : super(repaint: Listenable.merge([intro, outro]));

  final Animation<double> intro;
  final Animation<double> outro;
  final Palette palette;
  final Offset centre;
  final bool reduced;

  static double _slice(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final t = reduced ? 1.0 : intro.value;
    final o = reduced ? 0.0 : outro.value;
    const m = SplashOverlay.markSize;
    final rect = Offset.zero & size;

    // How far through the window the camera is. The glass has to outgrow
    // the screen's diagonal before the frame is out of sight.
    final zoom = Curves.easeInCubic.transform(o);
    final full =
        math.sqrt(size.width * size.width + size.height * size.height) /
        (MarkPainter.pane.width / 100 * m) *
        1.15;
    final scale = ui.lerpDouble(1, full, zoom)!;

    final pane = Rect.fromCenter(
      center: centre,
      width: MarkPainter.pane.width / 100 * m * scale,
      height: MarkPainter.pane.height / 100 * m * scale,
    );
    final glass = RRect.fromRectAndRadius(
      pane,
      Radius.circular(MarkPainter.paneRadius / 100 * m * scale),
    );

    // The night sky, with a hole where the glass is once the camera moves.
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        p.sky,
        const [0, .55, 1],
      );
    if (o == 0) {
      canvas.drawRect(rect, sky);
    } else {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect),
          Path()..addRRect(glass),
        ),
        sky,
      );
    }

    final rise = Curves.easeOutCubic.transform(_slice(t, .32, .8));
    if (o < 1) {
      // First light spilling from the window as the sun comes up.
      final glowR = m * (.9 + .35 * rise) * scale;
      final warm = Color.lerp(p.sun, p.cloud, .2)!;
      canvas.save();
      if (o > 0) {
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(rect),
            Path()..addRRect(glass),
          ),
        );
      }
      canvas.drawCircle(
        centre,
        glowR,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            centre,
            glowR,
            [
              warm.withValues(alpha: .34 * rise * (1 - _slice(o, 0, .22))),
              warm.withValues(alpha: .08 * rise * (1 - _slice(o, 0, .22))),
              warm.withValues(alpha: 0),
            ],
            const [0, .45, 1],
          ),
      );
      canvas.restore();
    }

    final box = m * scale;
    canvas.save();
    canvas.translate(centre.dx - box / 2, centre.dy - box / 2);
    MarkPainter(
      palette: p,
      frame: p.cloud,
      draw: Curves.easeInOutCubic.transform(_slice(t, 0, .34)),
      // Past 1 the shade goes on up out of the window as the camera nears.
      lift:
          Curves.easeInOutCubic.transform(_slice(t, .2, .62)) +
          .35 * _slice(o, 0, .4),
      rise: rise,
      paneOpacity: 1 - Curves.easeOut.transform(_slice(o, .05, .55)),
    ).paint(canvas, Size.square(box));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.palette != palette || old.centre != centre || old.reduced != reduced;
}

/// Starts [start] when the splash begins to leave (or at once if it already
/// has), so a first screen mounted early does not play its entrance unseen.
void startWhenRevealed(WidgetRef ref, VoidCallback start) {
  final phase = ref.read(splashPhaseProvider);
  if (phase == SplashPhase.leaving || phase == SplashPhase.done) {
    start();
    return;
  }
  late final ProviderSubscription<SplashPhase> sub;
  sub = ref.listenManual(splashPhaseProvider, (_, next) {
    if (next == SplashPhase.leaving || next == SplashPhase.done) {
      sub.close();
      start();
    }
  });
}

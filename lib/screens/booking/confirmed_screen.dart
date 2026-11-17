import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/trip.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sky_scene.dart';
import '../actions.dart';
import '../shell/main_shell.dart';
import '../trips/boarding_pass.dart';

/// Booked. Under the sky the boarding pass feeds out of a slot the way a
/// printer hands one over, in three pulls, and settles.
class ConfirmedScreen extends ConsumerStatefulWidget {
  const ConfirmedScreen({super.key, required this.tripIds});

  final List<String> tripIds;

  @override
  ConsumerState<ConfirmedScreen> createState() => _ConfirmedScreenState();
}

class _ConfirmedScreenState extends ConsumerState<ConfirmedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _print;
  final _pages = PageController(viewportFraction: .92);
  int _pulls = 0;

  @override
  void initState() {
    super.initState();
    _print = AnimationController(vsync: this, duration: Motion.print)
      ..addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _print.value = 1;
        return;
      }
      // Not until the page has mostly arrived: printing under the
      // cross-fade would go unseen.
      await Future<void>.delayed(Motion.handOff * .6);
      if (mounted) _print.forward();
    });
  }

  /// A light tap for each pull of the printer.
  void _tick() {
    final pull = (_print.value * 3).floor();
    if (pull > _pulls && pull <= 3) {
      _pulls = pull;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _print.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// Three pulls with a pause between: each third eases out on its own.
  static double _fed(double t) {
    const pulls = 3;
    final scaled = t * pulls;
    final done = scaled.floor().clamp(0, pulls - 1);
    final within = (scaled - done).clamp(0.0, 1.0);
    return (done + Curves.easeOutCubic.transform((within / .75).clamp(0, 1))) /
        pulls;
  }

  void _leave({Trip? open}) {
    // Search goes back to its first page behind this one.
    tabNavigatorKeys[ShellTab.home]!.currentState?.popUntil((r) => r.isFirst);
    // This page's own context goes with it: act through the container.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context, rootNavigator: true).pop();
    if (open != null) openTripIn(container, open);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final trips = [
      for (final id in widget.tripIds) ?ref.watch(tripProvider(id)),
    ];
    final world = ref.watch(worldProvider).valueOrNull;
    final city = trips.isEmpty
        ? ''
        : world?.maybeAirport(trips.first.flight.to)?.city ??
              trips.first.flight.to;
    final settled = CurvedAnimation(
      parent: _print,
      curve: const Interval(.8, 1, curve: Curves.easeOut),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: p.sky.first,
        child: SkyScene(
          sun: const Alignment(0, 1.05),
          child: Padding(
            padding: EdgeInsets.only(
              top: media.padding.top + Space.xl,
              bottom: media.padding.bottom + Space.lg,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Column(
                    children: [
                      Text(
                        'BOOKED',
                        style: context.label.copyWith(color: p.sun),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        'You are going to $city',
                        textAlign: TextAlign.center,
                        style: context.display.copyWith(color: p.onSky),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trips.length > 1
                            ? 'Two passes, one booking: ${trips.first.pnr}'
                            : 'Booking reference ${trips.isEmpty ? '' : trips.first.pnr}',
                        style: context.body.copyWith(color: p.onSkyMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                // The slot the pass comes out of.
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  height: 12,
                  decoration: BoxDecoration(
                    color: p.sky.first,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.onSky.withValues(alpha: .14)),
                  ),
                ),
                SizedBox(
                  height: BoardingPass.height + 8,
                  child: AnimatedBuilder(
                    animation: _print,
                    // The outer Align loosens the fixed height, so the inner
                    // one can be as short as the part that has fed out.
                    builder: (context, child) => Align(
                      alignment: Alignment.topCenter,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: _fed(_print.value).clamp(0.0, 1.0),
                          child: child,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      height: BoardingPass.height + 8,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: trips.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
                          child: FlipPass(trip: trips[i]),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: settled,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrimaryButton(
                          key: const Key('confirmed-view-trip'),
                          label: 'View trip',
                          onPressed: trips.isEmpty
                              ? null
                              : () => _leave(open: trips.first),
                        ),
                        const SizedBox(height: Space.sm),
                        TextButton(
                          key: const Key('confirmed-done'),
                          onPressed: _leave,
                          style: TextButton.styleFrom(
                            foregroundColor: p.onSky,
                            minimumSize: const Size.fromHeight(48),
                            textStyle: const TextStyle(
                              fontFamily: AppTheme.font,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          child: const Text('Back to search'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

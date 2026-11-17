import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../models/flight.dart';
import '../models/when.dart';
import '../providers/core_providers.dart';
import 'route_arc.dart';

/// The colours a [FlightLine] is drawn in, so the same widget sits on a
/// card, on the sky and on a boarding pass.
class FlightTone {
  const FlightTone({
    required this.ink,
    required this.muted,
    required this.line,
    required this.plane,
  });

  final Color ink;
  final Color muted;
  final Color line;
  final Color plane;

  factory FlightTone.card(BuildContext context) {
    final p = context.palette;
    return FlightTone(
      ink: p.ink,
      muted: p.muted,
      line: p.line,
      plane: p.accent,
    );
  }

  factory FlightTone.sky(BuildContext context) {
    final p = context.palette;
    return FlightTone(
      ink: p.onSky,
      muted: p.onSkyMuted,
      line: p.onSky.withValues(alpha: .3),
      plane: p.sun,
    );
  }

  factory FlightTone.pass(BuildContext context) {
    final p = context.palette;
    return FlightTone(
      ink: p.onPass,
      muted: p.onPass.withValues(alpha: .6),
      line: p.passLine.withValues(alpha: .4),
      plane: p.sun,
    );
  }
}

/// A flight in one line: where from and when, the path with how long it
/// takes, where to and when. Times are local to each airport.
class FlightLine extends ConsumerWidget {
  const FlightLine({
    super.key,
    required this.flight,
    this.progress,
    this.tone,
    this.codeSize = 30,
    this.times = true,
    this.arcHeight = 46,
  });

  final Flight flight;

  /// Where the plane is on the path. Defaults to the middle, at rest.
  final Animation<double>? progress;
  final FlightTone? tone;
  final double codeSize;
  final bool times;
  final double arcHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(worldProvider).valueOrNull;
    final t = tone ?? FlightTone.card(context);
    final from = world?.maybeAirport(flight.from);
    final to = world?.maybeAirport(flight.to);
    final late = flight.delayMin >= 15;

    Widget col(String code, String? city, DateTime? at, CrossAxisAlignment x) =>
        Column(
          crossAxisAlignment: x,
          children: [
            Text(
              code,
              style: context.code.copyWith(fontSize: codeSize, color: t.ink),
            ),
            const SizedBox(height: 3),
            Text(
              city ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption.copyWith(color: t.muted),
            ),
            if (times && at != null) ...[
              const SizedBox(height: 7),
              Text(
                When.time(at),
                style: context.price.copyWith(
                  fontSize: 14.5,
                  color: late ? context.palette.accent : t.ink,
                ),
              ),
            ],
          ],
        );

    Widget end(String code, String? city, DateTime? at, CrossAxisAlignment x) =>
        _Shrink(x: x, max: 104, child: col(code, city, at, x));

    return Semantics(
      label:
          '${from?.city ?? flight.from} to ${to?.city ?? flight.to}, ${When.span(flight.duration)}, ${flight.nonStop ? 'non-stop' : 'one stop in ${world?.maybeAirport(flight.via!)?.city ?? flight.via}'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          end(
            flight.from,
            from?.city,
            from?.local(flight.actualDepart),
            CrossAxisAlignment.start,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  SizedBox(
                    height: arcHeight,
                    child: RouteArc(
                      // At rest the plane sits clear of the stop's marker.
                      progress:
                          progress ??
                          AlwaysStoppedAnimation(flight.nonStop ? .5 : .3),
                      line: t.line,
                      flown: t.plane,
                      plane: t.plane,
                      stop: !flight.nonStop,
                      bow: .62,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${When.span(flight.duration)} · ${flight.nonStop ? 'Non-stop' : 'Via ${flight.via}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption.copyWith(
                      fontSize: 11.5,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          end(
            flight.to,
            to?.city,
            to?.local(flight.actualArrive),
            CrossAxisAlignment.end,
          ),
        ],
      ),
    );
  }
}

/// The same line with the hours in front: what a list of results compares.
class FlightLineTimes extends StatelessWidget {
  const FlightLineTimes({
    super.key,
    required this.flight,
    required this.leaves,
    required this.lands,
  });

  final Flight flight;
  final String leaves;
  final String lands;

  @override
  Widget build(BuildContext context) {
    final t = FlightTone.card(context);
    Widget col(String time, String code, CrossAxisAlignment x) => Column(
      crossAxisAlignment: x,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          time,
          style: context.price.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(code, style: context.title.copyWith(fontSize: 13, color: t.muted)),
      ],
    );
    Widget end(String time, String code, CrossAxisAlignment x) =>
        _Shrink(x: x, max: 112, child: col(time, code, x));

    return Semantics(
      label:
          '${flight.from} $leaves to ${flight.to} $lands, ${When.span(flight.duration)}, ${flight.nonStop ? 'non-stop' : 'one stop'}',
      excludeSemantics: true,
      child: Row(
        children: [
          end(leaves, flight.from, CrossAxisAlignment.start),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                    child: RouteArc(
                      progress: AlwaysStoppedAnimation(
                        flight.nonStop ? .5 : .3,
                      ),
                      line: t.line,
                      flown: t.plane,
                      plane: t.plane,
                      stop: !flight.nonStop,
                      bow: .6,
                      planeSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${When.span(flight.duration)} · ${flight.nonStop ? 'Non-stop' : 'Via ${flight.via}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
          end(lands, flight.to, CrossAxisAlignment.end),
        ],
      ),
    );
  }
}

/// Keeps an end of the line inside [max] by scaling it down, so very large
/// text shrinks rather than pushing the path off the card.
class _Shrink extends StatelessWidget {
  const _Shrink({required this.x, required this.max, required this.child});

  final CrossAxisAlignment x;
  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: max),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: x == CrossAxisAlignment.start
          ? Alignment.topLeft
          : Alignment.topRight,
      child: child,
    ),
  );
}

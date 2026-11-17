import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/flight.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/route_arc.dart';

/// A flight being followed: where the plane is on its path right now, the
/// times it was due and the times it is making, and its gate.
///
/// The plane flies in from the start of the path to where it really is
/// when the card first shows, and moves on as the minutes pass.
class StatusCard extends ConsumerStatefulWidget {
  const StatusCard({
    super.key,
    required this.flight,
    this.trailing,
    this.onTap,
  });

  final Flight flight;

  /// The action at the top right: follow, or stop following.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  ConsumerState<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<StatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _plane;

  double get _target {
    final s = FlightStatus.of(widget.flight, ref.read(nowProvider));
    return switch (s.phase) {
      FlightPhase.inAir => s.progress,
      FlightPhase.landed => 1,
      _ => 0,
    };
  }

  @override
  void initState() {
    super.initState();
    _plane = AnimationController(vsync: this, duration: Motion.flight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fly());
    ref.listenManual(nowProvider, (_, _) => _fly());
  }

  void _fly() {
    if (!mounted) return;
    if (Motion.reduced(context)) {
      _plane.value = _target;
    } else {
      _plane.animateTo(_target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void didUpdateWidget(StatusCard old) {
    super.didUpdateWidget(old);
    if (old.flight.id != widget.flight.id) _fly();
  }

  @override
  void dispose() {
    _plane.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = widget.flight;
    final status = FlightStatus.of(f, ref.watch(nowProvider));
    final world = ref.watch(worldProvider).valueOrNull;
    final from = world?.maybeAirport(f.from);
    final to = world?.maybeAirport(f.to);
    final off = status.phase == FlightPhase.cancelled;

    Widget end(
      String code,
      String? city,
      DateTime? due,
      DateTime? now,
      CrossAxisAlignment x,
    ) => Column(
      crossAxisAlignment: x,
      children: [
        Text(code, style: context.code.copyWith(fontSize: 28)),
        const SizedBox(height: 2),
        Text(city ?? '', maxLines: 1, style: context.caption),
        const SizedBox(height: 6),
        if (due != null && now != null) ...[
          if (status.delayed)
            Text(
              When.time(due),
              style: context.caption.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: p.muted,
              ),
            ),
          Text(
            When.time(off ? due : now),
            style: context.price.copyWith(
              fontSize: 15,
              color: status.delayed ? p.accent : p.ink,
              decoration: off ? TextDecoration.lineThrough : null,
              decorationColor: p.ink,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: widget.onTap != null,
      label:
          '${f.code}, ${from?.city ?? f.from} to ${to?.city ?? f.to}, ${status.headline}, ${status.line}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.sm,
            Space.lg,
          ),
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.ink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      f.code,
                      style: context.label.copyWith(
                        color: p.paper,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: StatusChip(
                      status.headline,
                      live: status.live || status.delayed,
                      error: off,
                    ),
                  ),
                  const Spacer(),
                  widget.trailing ?? const SizedBox(height: 44),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    end(
                      f.from,
                      from?.city,
                      from?.local(f.depart),
                      from?.local(f.actualDepart),
                      CrossAxisAlignment.start,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 62,
                              child: Opacity(
                                opacity: off ? .35 : 1,
                                child: RouteArc(
                                  progress: _plane,
                                  line: p.line,
                                  flown: p.accent,
                                  plane: off ? p.muted : p.accent,
                                  planeSize: 22,
                                  stroke: 2,
                                  stop: !f.nonStop,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: context.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: status.live ? p.accent : p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    end(
                      f.to,
                      to?.city,
                      to?.local(f.arrive),
                      to?.local(f.actualArrive),
                      CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ),
              if (!off) ...[
                const SizedBox(height: Space.md),
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Row(
                    children: [
                      _Fact('Terminal', f.terminal),
                      _Fact('Gate', f.gate),
                      _Fact(
                        status.phase == FlightPhase.landed
                            ? 'Belt'
                            : 'Flight time',
                        status.phase == FlightPhase.landed
                            ? f.belt
                            : When.span(f.duration),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: Space.sm),
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 9),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              style: context.caption.copyWith(fontSize: 11),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.price,
            ),
          ],
        ),
      ),
    );
  }
}

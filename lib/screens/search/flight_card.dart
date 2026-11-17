import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/flight.dart';
import '../../models/money.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ticket.dart';

/// One flight as a ticket: the airline and the flight, the path, and on the
/// stub the seats left and the fare.
class FlightCard extends ConsumerStatefulWidget {
  const FlightCard({
    super.key,
    required this.flight,
    required this.onSelect,
    this.best = false,
  });

  final Flight flight;

  /// Called with where on screen the card was tapped.
  final ValueChanged<Offset> onSelect;
  final bool best;

  @override
  ConsumerState<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends ConsumerState<FlightCard> {
  Offset _at = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = widget.flight;
    final airline = ref.watch(worldProvider).valueOrNull?.airline(f.airline);
    return Listener(
      onPointerDown: (e) => _at = e.position,
      child: Pressable(
        key: Key('flight-${f.id}'),
        scale: .98,
        semanticLabel: 'Select ${f.code}, ${money(f.priceCents)}',
        onTap: () => widget.onSelect(_at),
        child: Material(
          color: p.card,
          shape: TicketShape(notchAt: 116, side: BorderSide(color: p.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  0,
                ),
                child: Row(
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
                        f.airline,
                        style: context.label.copyWith(
                          color: p.paper,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        '${airline?.name ?? ''} · ${f.code}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption,
                      ),
                    ),
                    if (widget.best) const StatusChip('Best fare', live: true),
                  ],
                ),
              ),
              SizedBox(
                height: 88,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.sm,
                    Space.lg,
                    0,
                  ),
                  child: _TimesLine(flight: f),
                ),
              ),
              const Perforation(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.md,
                  Space.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.seatsLeft <= 4
                            ? '${f.seatsLeft} ${f.seatsLeft == 1 ? 'seat' : 'seats'} left at this fare'
                            : 'Carry-on and a checked bag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption.copyWith(
                          color: f.seatsLeft <= 4 ? p.accent : p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      money(f.priceCents),
                      style: context.price.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        'Select',
                        style: context.title.copyWith(
                          fontSize: 13.5,
                          color: p.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Times first, codes under them: on a results list the hour is what is
/// being compared.
class _TimesLine extends ConsumerWidget {
  const _TimesLine({required this.flight});

  final Flight flight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(worldProvider).valueOrNull;
    final from = world?.maybeAirport(flight.from);
    final to = world?.maybeAirport(flight.to);
    final leaves = from?.local(flight.depart);
    final lands = to?.local(flight.arrive);
    final nextDay =
        leaves != null && lands != null && !When.sameDay(leaves, lands);
    return FlightLineTimes(
      flight: flight,
      leaves: leaves == null ? '' : When.time(leaves),
      lands: lands == null ? '' : '${When.time(lands)}${nextDay ? ' +1' : ''}',
    );
  }
}

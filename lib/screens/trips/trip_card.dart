import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/pressable.dart';
import '../../widgets/ticket.dart';

/// A trip in a list: the route as a ticket, with the day, the seat and
/// where the flight is in its day on the stub.
class TripCard extends ConsumerWidget {
  const TripCard({super.key, required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = trip.flight;
    final now = ref.watch(nowProvider);
    final status = FlightStatus.of(f, now);
    final world = ref.watch(worldProvider).valueOrNull;
    final day = world?.maybeAirport(f.from)?.local(f.actualDepart) ?? f.depart;
    final gone = trip.isCancelled;
    return Pressable(
      key: Key('trip-${trip.id}'),
      scale: .98,
      semanticLabel:
          'Trip ${f.from} to ${f.to}, ${When.day(day)}, ${gone ? 'cancelled' : status.headline}',
      onTap: onTap,
      child: Material(
        color: p.card,
        shape: TicketShape(notchAt: 118, side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: gone ? .6 : 1,
          child: Column(
            children: [
              SizedBox(
                height: 118,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.lg,
                    Space.lg,
                    0,
                  ),
                  child: FlightLine(
                    flight: f,
                    codeSize: 26,
                    arcHeight: 34,
                    progress: AlwaysStoppedAnimation(
                      status.phase == FlightPhase.inAir
                          ? status.progress
                          : status.phase == FlightPhase.landed
                          ? 1
                          : 0,
                    ),
                  ),
                ),
              ),
              const Perforation(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  Space.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${When.day(day)} · ${trip.seats.length == 1 ? 'Seat' : 'Seats'} ${trip.seats.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.title.copyWith(fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    StatusChip(
                      gone
                          ? 'Cancelled'
                          : trip.checkedIn &&
                                status.phase == FlightPhase.checkIn
                          ? 'Checked in'
                          : status.headline,
                      live: !gone && (status.live || status.delayed),
                      error: gone,
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

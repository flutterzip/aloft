import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../models/flight.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/ticket.dart';

/// One flight on the review page, as a ticket with its seats on the stub.
class BookingLeg extends StatelessWidget {
  const BookingLeg({
    super.key,
    required this.title,
    required this.flight,
    required this.day,
    required this.seats,
    required this.onSeats,
    required this.index,
  });

  final String title;
  final Flight flight;
  final String day;
  final List<String> seats;
  final VoidCallback onSeats;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      shape: TicketShape(notchAt: 150, side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: context.label.copyWith(color: p.muted),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          '$day · ${flight.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  FlightLine(flight: flight, codeSize: 26, arcHeight: 34),
                ],
              ),
            ),
          ),
          const Perforation(),
          Semantics(
            button: true,
            label: 'Seats ${seats.join(', ')}, change',
            excludeSemantics: true,
            child: InkWell(
              key: Key('booking-seats-$index'),
              onTap: onSeats,
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.airline_seat_recline_normal_rounded,
                        size: 18,
                        color: p.ink,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          seats.isEmpty
                              ? 'Seats given at check-in'
                              : '${seats.length == 1 ? 'Seat' : 'Seats'} ${seats.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.title.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        'Choose',
                        style: context.title.copyWith(
                          fontSize: 13.5,
                          color: p.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Someone who can be put on the booking; chosen ones carry a tick.
class TravellerChip extends StatelessWidget {
  const TravellerChip({
    super.key,
    required this.traveller,
    required this.order,
    required this.onTap,
  });

  final Traveller traveller;

  /// The traveller's place on the booking, or -1 if not flying.
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = order >= 0;
    return Semantics(
      button: true,
      selected: on,
      label: traveller.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('booking-traveller-${traveller.id}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.only(left: 6, right: 14),
          decoration: BoxDecoration(
            color: on ? p.accentWash : p.card,
            border: Border.all(color: on ? p.accent : p.line),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? p.accent : p.field,
                  shape: BoxShape.circle,
                ),
                child: on
                    ? Icon(Icons.check_rounded, size: 16, color: p.onAccent)
                    : Text(
                        traveller.name.characters.first.toUpperCase(),
                        style: context.title.copyWith(fontSize: 13),
                      ),
              ),
              const SizedBox(width: Space.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  traveller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../config/palette.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/aloft_mark.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/ticket.dart';

/// The boarding pass for [trip]: dark card stock with fine line work, the
/// route, and the four things read at the airport (date, boarding time,
/// gate, seat). Below the tear is the booking reference.
///
/// The pass is the same card wherever it appears: on the trips tab, in the
/// pass sheet, on a trip's page and on the confirmation.
class BoardingPass extends ConsumerWidget {
  const BoardingPass({super.key, required this.trip, this.traveller = 0});

  final Trip trip;

  /// Whose pass this is, as an index into the trip's travellers.
  final int traveller;

  static const tear = 232.0;
  static const height = 306.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = trip.flight;
    final world = ref.watch(worldProvider).valueOrNull;
    final from = world?.maybeAirport(f.from);
    final leaves = from?.local(f.actualDepart) ?? f.actualDepart;
    final boards = leaves.subtract(FlightStatus.boardingOpens);
    final name =
        trip.travellers[traveller.clamp(0, trip.travellers.length - 1)];
    final seat = trip.seats[traveller.clamp(0, trip.seats.length - 1)];
    return Semantics(
      label:
          'Boarding pass, $name, ${f.code}, ${f.from} to ${f.to}, ${When.day(leaves)}, boards ${When.time(boards)}, gate ${f.gate}, seat $seat',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Material(
          color: p.pass,
          shape: const TicketShape(notchAt: tear, radius: 26, notch: 11),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _LineWork(p),
            child: Column(
              children: [
                SizedBox(
                  height: tear,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AloftMark(size: 26, frame: p.onPass),
                            const SizedBox(width: 6),
                            Text(
                              'BOARDING PASS',
                              style: context.label.copyWith(color: p.onPass),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${world?.airline(f.airline).name ?? ''} · ${f.code}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: context.caption.copyWith(
                                  color: p.onPass.withValues(alpha: .7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.title.copyWith(
                            color: p.onPass,
                            letterSpacing: .6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FlightLine(
                          flight: f,
                          tone: FlightTone.pass(context),
                          times: false,
                          codeSize: 34,
                          arcHeight: 40,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _Cell(
                              'DATE',
                              '${leaves.day} ${When.month(leaves)}',
                            ),
                            _Cell('BOARDS', When.time(boards)),
                            _Cell('GATE', f.gate),
                            _Cell('SEAT', seat, strong: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Perforation(color: p.passLine.withValues(alpha: .45)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _Cell('BOOKING', trip.pnr),
                        _Cell('CABIN', trip.cabin.label),
                        _Cell('TERMINAL', f.terminal),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              trip.checkedIn ? 'CHECKED IN' : 'TAP TO TURN',
                              style: context.label.copyWith(
                                fontSize: 9,
                                color: trip.checkedIn
                                    ? p.sun
                                    : p.onPass.withValues(alpha: .5),
                              ),
                            ),
                          ),
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

/// The other side of the pass: the barcode scanned at the gate once the
/// trip is checked in, and until then when check-in opens.
class BoardingPassBack extends ConsumerWidget {
  const BoardingPassBack({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final now = ref.watch(nowProvider);
    final status = FlightStatus.of(trip.flight, now);
    final opensIn = status.untilDepart - FlightStatus.checkInOpens;
    final ticket =
        '${AppBrand.ticketPrefix}${stableHash(trip.id) % 900000 + 100000}';
    return SizedBox(
      height: BoardingPass.height,
      child: Material(
        color: p.pass,
        shape: const TicketShape(
          notchAt: BoardingPass.tear,
          radius: 26,
          notch: 11,
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _LineWork(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trip.checkedIn ? 'SCAN AT THE GATE' : 'NOT CHECKED IN YET',
                  style: context.label.copyWith(color: p.onPass),
                ),
                const SizedBox(height: 14),
                if (trip.checkedIn)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.onPass,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Barcode(
                      data: '${trip.pnr}${trip.flight.id}',
                      color: p.pass,
                      height: 96,
                    ),
                  )
                else
                  SizedBox(
                    height: 124,
                    child: Center(
                      child: Text(
                        trip.isCancelled
                            ? 'This trip was cancelled.'
                            : opensIn > Duration.zero
                            ? 'Check-in opens in ${When.span(opensIn)}.\nYour barcode appears here once you check in.'
                            : 'Check in and your barcode appears here.',
                        textAlign: TextAlign.center,
                        style: context.body.copyWith(
                          color: p.onPass.withValues(alpha: .75),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    _Cell('TICKET', ticket),
                    _Cell('SEATS', trip.seats.join(' ')),
                    _Cell('BELT', trip.flight.belt),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            style: context.label.copyWith(
              fontSize: 8.5,
              letterSpacing: 1.4,
              color: p.onPass.withValues(alpha: .55),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.price.copyWith(
              fontSize: strong ? 17 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? p.sun : p.onPass,
            ),
          ),
        ],
      ),
    );
  }
}

/// The security printing on the pass: the lines of a globe seen from one
/// corner, fine enough to catch the eye only when the card moves.
class _LineWork extends CustomPainter {
  const _LineWork(this.palette);

  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = palette.passLine.withValues(alpha: .1);
    final centre = Offset(size.width * 1.02, size.height * 1.1);
    for (var i = 1; i <= 9; i++) {
      canvas.drawCircle(centre, size.width * .13 * i, paint);
    }
    for (var i = 0; i < 9; i++) {
      final a = math.pi + i * math.pi / 16;
      canvas.drawLine(
        centre,
        centre + Offset(math.cos(a), math.sin(a)) * size.width * 1.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LineWork old) => old.palette != palette;
}

/// A pass that turns over when tapped, about its vertical axis, with a
/// little lift at the half-way point.
class FlipPass extends StatefulWidget {
  const FlipPass({super.key, required this.trip, this.traveller = 0});

  final Trip trip;
  final int traveller;

  @override
  State<FlipPass> createState() => FlipPassState();
}

class FlipPassState extends State<FlipPass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn;

  @override
  void initState() {
    super.initState();
    _turn = AnimationController(vsync: this, duration: Motion.flip);
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  bool get showingBack => _turn.value > .5;

  /// Turns the pass to its barcode side, or back.
  void flip({bool? toBack}) {
    final back = toBack ?? !showingBack;
    HapticFeedback.selectionClick();
    if (Motion.reduced(context)) {
      _turn.value = back ? 1 : 0;
    } else {
      back ? _turn.forward() : _turn.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final front = BoardingPass(trip: widget.trip, traveller: widget.traveller);
    final back = BoardingPassBack(trip: widget.trip);
    return Semantics(
      button: true,
      hint: 'Turns the pass over',
      child: GestureDetector(
        key: const Key('pass-flip'),
        onTap: flip,
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_turn.value);
            final angle = t * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..scaleByDouble(
                  1 + .05 * math.sin(angle),
                  1 + .05 * math.sin(angle),
                  1,
                  1,
                )
                ..rotateY(showBack ? angle - math.pi : angle),
              child: showBack ? back : front,
            );
          },
        ),
      ),
    );
  }
}

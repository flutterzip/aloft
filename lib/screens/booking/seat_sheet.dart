import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/airport.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/primary_button.dart';

/// Picks a seat for each traveller on [flight]. Resolves to the seats in
/// traveller order, or null if the sheet was dismissed.
Future<List<String>?> showSeatSheet(
  BuildContext context, {
  required Flight flight,
  required Cabin cabin,
  required List<String> travellers,
  required List<String> seats,
}) => showAppSheet<List<String>>(
  context,
  title: 'Choose seats, ${flight.from} to ${flight.to}',
  builder: (_) => _SeatSheet(
    flight: flight,
    cabin: cabin,
    travellers: travellers,
    seats: seats,
  ),
);

class _SeatSheet extends StatefulWidget {
  const _SeatSheet({
    required this.flight,
    required this.cabin,
    required this.travellers,
    required this.seats,
  });

  final Flight flight;
  final Cabin cabin;
  final List<String> travellers;
  final List<String> seats;

  @override
  State<_SeatSheet> createState() => _SeatSheetState();
}

class _SeatSheetState extends State<_SeatSheet> {
  late final List<String> _seats = [...widget.seats];
  late final _map = SeatMap(widget.flight.id, widget.cabin, mine: widget.seats);

  /// Whose seat the next tap sets.
  int _active = 0;

  void _tap(String seat) {
    final holder = _seats.indexOf(seat);
    if (holder >= 0) {
      // Tapping a seat already picked hands the next tap to its traveller.
      setState(() => _active = holder);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _seats[_active] = seat;
      _active = (_active + 1) % _seats.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final letters = _map.letters;
    final half = letters.length ~/ 2;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              itemCount: widget.travellers.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, i) {
                final on = i == _active;
                return Semantics(
                  button: true,
                  selected: on,
                  label: '${widget.travellers[i]}, seat ${_seats[i]}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: Key('seat-traveller-$i'),
                    onTap: () => setState(() => _active = i),
                    child: AnimatedContainer(
                      duration: Motion.quick,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: on ? p.accentWash : p.field,
                        border: Border.all(color: on ? p.accent : p.field),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.travellers[i].split(' ').first,
                                style: context.caption,
                              ),
                              AnimatedSwitcher(
                                duration: Motion.quick,
                                child: Text(
                                  _seats[i],
                                  key: ValueKey(_seats[i]),
                                  style: context.title.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: on ? p.accent : p.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.sm,
            ),
            child: Wrap(
              spacing: Space.lg,
              runSpacing: 4,
              children: [
                _Legend(color: p.card, border: p.muted, label: 'Free'),
                _Legend(color: p.seatTaken, label: 'Taken'),
                _Legend(color: p.accent, label: 'Yours'),
                _Legend(
                  color: p.card,
                  border: p.accent,
                  label: 'Extra legroom',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.lg,
              ),
              itemCount: _map.rowCount + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var c = 0; c < letters.length; c++) ...[
                          if (c == half) const SizedBox(width: 44),
                          SizedBox(
                            width: _Seat.size + 8,
                            child: Text(
                              letters[c],
                              textAlign: TextAlign.center,
                              style: context.caption,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                final row = _map.firstRow + i - 1;
                final roomy = _map.extraLegroom(row);
                return Padding(
                  // Rows with more legroom stand a little apart, as on the
                  // plane.
                  padding: EdgeInsets.only(top: roomy ? 14 : 0, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var c = 0; c < letters.length; c++) ...[
                        if (c == half)
                          SizedBox(
                            width: 44,
                            child: Text(
                              '$row',
                              textAlign: TextAlign.center,
                              style: context.caption,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _Seat(
                            seat: '$row${letters[c]}',
                            taken: _map.taken('$row${letters[c]}'),
                            mine: _seats.indexOf('$row${letters[c]}'),
                            roomy: roomy,
                            onTap: _tap,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.lg,
            ),
            child: PrimaryButton(
              key: const Key('seat-confirm'),
              label: _seats.length == 1
                  ? 'Confirm seat ${_seats.single}'
                  : 'Confirm seats ${_seats.join(', ')}',
              onPressed: () => Navigator.of(context).pop(_seats),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.seat,
    required this.taken,
    required this.mine,
    required this.roomy,
    required this.onTap,
  });

  final String seat;
  final bool taken;

  /// The index of the traveller sitting here, or -1.
  final int mine;
  final bool roomy;
  final ValueChanged<String> onTap;

  static const size = 38.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chosen = mine >= 0;
    return Semantics(
      button: true,
      enabled: !taken,
      selected: chosen,
      label:
          'Seat $seat${taken ? ', taken' : ''}${roomy ? ', extra legroom' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('seat-$seat'),
        behavior: HitTestBehavior.opaque,
        onTap: taken ? null : () => onTap(seat),
        child: AnimatedScale(
          scale: chosen ? 1.08 : 1,
          duration: Motion.short,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: Motion.quick,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chosen
                  ? p.accent
                  : taken
                  ? p.seatTaken
                  : p.card,
              border: Border.all(
                color: chosen
                    ? p.accent
                    : taken
                    ? p.seatTaken
                    : roomy
                    ? p.accent
                    : p.muted,
                width: 1.3,
              ),
              // A seat: rounder at the back than at the knees.
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: Radius.circular(7),
              ),
            ),
            child: chosen
                ? Text(
                    '${mine + 1}',
                    style: context.title.copyWith(
                      fontSize: 13,
                      color: p.onAccent,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: border ?? color, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.caption),
    ],
  );
}

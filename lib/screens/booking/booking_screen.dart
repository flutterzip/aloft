import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aloft/kit/kit.dart';

import '../../app.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../models/flight.dart';
import '../../models/money.dart';
import '../../models/trip.dart';
import '../../models/when.dart';
import '../../providers/account_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../services/trip_repository.dart';
import '../../widgets/common.dart';
import '../profile/card_sheet.dart';
import '../profile/traveller_sheet.dart';
import 'booking_parts.dart';
import 'confirmed_screen.dart';
import 'seat_sheet.dart';

abstract final class BookingKeys {
  static const pay = Key('booking-pay');
  static const card = Key('booking-card');
  static const addTraveller = Key('booking-add-traveller');
}

/// Review and pay: the flights picked, who is flying and where they sit,
/// the card, the price, and one button that pays.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.query, required this.flights});

  final SearchQuery query;

  /// One flight, or the way out and the way back.
  final List<Flight> flights;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  /// The seats on each flight, in traveller order.
  late final List<List<String>> _seats = [
    for (final f in widget.flights)
      SeatMap(f.id, widget.query.cabin).suggest(widget.query.adults),
  ];

  /// The ids of the travellers flying, in the order they were chosen.
  /// Null until the saved travellers have loaded.
  List<String>? _chosen;
  String? _error;
  String _failLabel = 'Payment failed. Try again';
  List<Trip> _booked = const [];

  int get _count => widget.query.adults;
  int get _total =>
      widget.flights.fold(0, (sum, f) => sum + f.priceCents) * _count;

  List<String> _picked(List<Traveller> all) {
    // Not before the saved travellers are in: an empty first answer would
    // stick, and nobody would be chosen.
    if (_chosen == null && all.isEmpty) return const [];
    return _chosen ??= [for (final t in all.take(_count)) t.id];
  }

  void _toggle(Traveller t, List<Traveller> all) {
    HapticFeedback.selectionClick();
    final chosen = _picked(all);
    setState(() {
      _error = null;
      if (chosen.contains(t.id)) {
        chosen.remove(t.id);
      } else {
        // Choosing one more than there are seats swaps the oldest out.
        if (chosen.length >= _count) chosen.removeAt(0);
        chosen.add(t.id);
      }
    });
  }

  List<String> _names(List<Traveller> all) => [
    for (final id in _picked(all))
      for (final t in all)
        if (t.id == id) t.name,
  ];

  Future<void> _changeSeats(int leg, List<Traveller> all) async {
    final names = _names(all);
    final picked = await showSeatSheet(
      context,
      flight: widget.flights[leg],
      cabin: widget.query.cabin,
      travellers: [
        for (var i = 0; i < _count; i++)
          i < names.length ? names[i] : 'Traveller ${i + 1}',
      ],
      seats: _seats[leg],
    );
    if (picked != null) setState(() => _seats[leg] = picked);
  }

  Future<bool> _pay(List<Traveller> all, PaymentCard? card) async {
    final names = _names(all);
    String? problem;
    if (names.length < _count) {
      final missing = _count - names.length;
      problem =
          'Choose $missing more ${missing == 1 ? 'traveller' : 'travellers'} to book $_count ${_count == 1 ? 'seat' : 'seats'}.';
    } else if (card == null) {
      problem = 'Add a card to pay with.';
    }
    if (problem != null) {
      setState(() {
        _error = problem;
        _failLabel = 'Something is missing';
      });
      return false;
    }
    setState(() => _error = null);
    try {
      _booked = await ref
          .read(tripsProvider.notifier)
          .book(
            legs: [
              for (var i = 0; i < widget.flights.length; i++)
                (flight: widget.flights[i], seats: _seats[i]),
            ],
            cabin: widget.query.cabin,
            travellers: names,
            card: card!,
          );
      return true;
    } on PaymentDeclined {
      if (mounted) {
        setState(() {
          _error =
              '${card!.masked} was declined. Nothing was charged. Choose another card.';
          _failLabel = 'Card declined';
        });
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The booking did not go through. Try again.';
          _failLabel = 'Payment failed. Try again';
        });
      }
      return false;
    }
  }

  void _paid() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      handOffRoute(ConfirmedScreen(tripIds: [for (final t in _booked) t.id])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final travellers =
        ref.watch(travellersProvider).valueOrNull ?? const <Traveller>[];
    final card = ref.watch(defaultCardProvider);
    final world = ref.watch(worldProvider).valueOrNull;
    final chosen = _picked(travellers);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: SubPage(
        title: 'Review and pay',
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.lg,
                  Space.gutter,
                  Space.xl,
                ),
                children: [
                  for (var i = 0; i < widget.flights.length; i++) ...[
                    BookingLeg(
                      title: widget.flights.length == 1
                          ? 'Your flight'
                          : i == 0
                          ? 'Flight out'
                          : 'Flight back',
                      flight: widget.flights[i],
                      day: When.day(
                        world
                                ?.maybeAirport(widget.flights[i].from)
                                ?.local(widget.flights[i].depart) ??
                            widget.flights[i].depart,
                      ),
                      seats: _seats[i],
                      onSeats: () => _changeSeats(i, travellers),
                      index: i,
                    ),
                    const SizedBox(height: Space.md),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    _count == 1
                        ? 'WHO IS FLYING'
                        : 'WHO IS FLYING, CHOOSE $_count',
                    style: context.label.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final t in travellers)
                        TravellerChip(
                          traveller: t,
                          order: chosen.indexOf(t.id),
                          onTap: () => _toggle(t, travellers),
                        ),
                      Semantics(
                        button: true,
                        label: 'Add a traveller',
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: BookingKeys.addTraveller,
                          onTap: () async {
                            final added = await showTravellerSheet(context);
                            if (added == null || !mounted) return;
                            _toggle(
                              added,
                              ref.read(travellersProvider).valueOrNull ??
                                  const [],
                            );
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: p.muted),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 18, color: p.ink),
                                const SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: context.title.copyWith(fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Text(
                    'PAY WITH',
                    style: context.label.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: Space.md),
                  Semantics(
                    button: true,
                    label: card == null
                        ? 'Add a card'
                        : 'Pay with ${card.masked}, change',
                    excludeSemantics: true,
                    child: InkWell(
                      key: BookingKeys.card,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onTap: () async {
                        if (card == null) {
                          await showCardSheet(context);
                        } else {
                          final id = await showCardPicker(
                            context,
                            selected: card.id,
                          );
                          if (id != null) {
                            ref.read(defaultCardIdProvider.notifier).choose(id);
                          }
                        }
                        if (mounted) setState(() => _error = null);
                      },
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg,
                        ),
                        decoration: BoxDecoration(
                          color: p.card,
                          border: Border.all(color: p.line),
                          borderRadius: BorderRadius.circular(Radii.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 20,
                              color: p.ink,
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Text(
                                card?.masked ?? 'Add a card',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.title,
                              ),
                            ),
                            Text(
                              card == null ? 'Add' : 'Change',
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
                  const SizedBox(height: Space.xl),
                  for (final f in widget.flights)
                    ReceiptRow(
                      '${f.from} to ${f.to}, $_count x ${money(f.priceCents)}',
                      money(f.priceCents * _count),
                    ),
                  const ReceiptRow('Taxes and fees', 'Included'),
                  Divider(color: p.line, height: Space.xl),
                  ReceiptRow('Total', money(_total), strong: true),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                media.padding.bottom + Space.md,
              ),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Notice(_error!, error: true),
                    const SizedBox(height: Space.md),
                  ],
                  KeyedSubtree(
                    key: BookingKeys.pay,
                    child: PayButton(
                      label: 'Pay ${money(_total)}',
                      paidLabel: 'Booked',
                      failedLabel: _failLabel,
                      color: p.accent,
                      foreground: p.onAccent,
                      onPay: () => _pay(travellers, card),
                      onPaid: _paid,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../models/flight.dart';
import '../../models/money.dart';
import '../../models/trip.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../booking/seat_sheet.dart';
import '../profile/records.dart';
import '../shell/main_shell.dart';
import 'boarding_pass.dart';
import 'check_in.dart';

abstract final class TripKeys {
  static const checkIn = Key('trip-check-in');
  static const seats = Key('trip-seats');
  static const follow = Key('trip-follow');
  static const cancel = Key('trip-cancel');
}

/// One trip: its pass, where the flight is in its day, the details, and
/// what can still be done about it (check in, change seats, follow, cancel).
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final _pass = GlobalKey<FlipPassState>();
  bool _checkingIn = false;

  Future<void> _cancel(Trip trip) async {
    final yes = await confirmRemove(
      context,
      title: 'Cancel this trip?',
      message:
          '${trip.flight.from} to ${trip.flight.to} on ${When.day(trip.flight.depart)}. ${money(trip.totalCents)} goes back to the card you paid with.',
      action: 'Cancel trip',
    );
    if (!yes || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final palette = context.palette;
    final trips = ref.read(tripsProvider.notifier);
    await trips.cancel(trip);
    HapticFeedback.mediumImpact();
    showToastOn(
      messenger,
      palette,
      'Trip cancelled',
      onUndo: () => trips.restore(trip),
    );
  }

  Future<void> _seats(Trip trip) async {
    final picked = await showSeatSheet(
      context,
      flight: trip.flight,
      cabin: trip.cabin,
      travellers: trip.travellers,
      seats: trip.seats,
    );
    if (picked == null || !mounted) return;
    await ref.read(tripsProvider.notifier).changeSeats(trip, picked);
    if (mounted) showToast(context, 'Seats changed to ${picked.join(', ')}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trip = ref.watch(tripProvider(widget.tripId));
    if (trip == null) {
      return const SubPage(
        title: 'Trip',
        child: Center(
          child: EmptyState(
            title: 'This trip is no longer here',
            message: 'It may have been removed when the demo data was reset.',
          ),
        ),
      );
    }
    final now = ref.watch(nowProvider);
    final f = trip.flight;
    final status = FlightStatus.of(f, now);
    final world = ref.watch(worldProvider).valueOrNull;
    final from = world?.maybeAirport(f.from);
    final to = world?.maybeAirport(f.to);
    final tracked = ref
        .watch(trackedProvider)
        .contains(normaliseFlightCode(f.code));
    final past = trip.isPast(now);
    final open = !trip.isCancelled && !past;
    final canSeat = open && status.phase.index < FlightPhase.boarding.index;

    return SubPage(
      title: '${from?.city ?? f.from} to ${to?.city ?? f.to}',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.lg,
          Space.gutter,
          MediaQuery.paddingOf(context).bottom + Sizes.tabBarReserve,
        ),
        children: [
          Row(
            children: [
              StatusChip(
                trip.isCancelled ? 'Cancelled' : status.headline,
                live: !trip.isCancelled && (status.live || status.delayed),
                error: trip.isCancelled,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  trip.cancelled ? 'You cancelled this trip' : status.line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          FlipPass(key: _pass, trip: trip),
          const SizedBox(height: Space.lg),
          if (trip.canCheckIn(now) || _checkingIn)
            PrimaryButton(
              key: TripKeys.checkIn,
              label: 'Check in now',
              icon: Icons.how_to_reg_outlined,
              busy: _checkingIn,
              onPressed: () async {
                setState(() => _checkingIn = true);
                await checkIn(context, ref, trip);
                if (!mounted) return;
                setState(() => _checkingIn = false);
                _pass.currentState?.flip(toBack: true);
              },
            )
          else if (open &&
              !trip.checkedIn &&
              status.phase == FlightPhase.scheduled)
            Notice(
              'Check-in opens ${When.span(status.untilDepart - FlightStatus.checkInOpens)} from now, a day before departure.',
            )
          else if (open && !trip.checkedIn)
            const Notice(
              'Online check-in has closed. Check in at the desk in the terminal.',
            ),
          const SizedBox(height: Space.xl),
          Text('THE DAY', style: context.label.copyWith(color: p.muted)),
          const SizedBox(height: Space.md),
          _Timeline(trip: trip, status: status),
          const SizedBox(height: Space.xl),
          Text('DETAILS', style: context.label.copyWith(color: p.muted)),
          const SizedBox(height: Space.sm),
          ReceiptRow(
            'Flight',
            '${world?.airline(f.airline).name ?? ''} ${f.code}',
          ),
          ReceiptRow(
            'Departs',
            from == null
                ? ''
                : '${When.day(from.local(f.actualDepart))}, ${When.time(from.local(f.actualDepart))}',
          ),
          ReceiptRow(
            'Arrives',
            to == null
                ? ''
                : '${When.day(to.local(f.actualArrive))}, ${When.time(to.local(f.actualArrive))}',
          ),
          ReceiptRow('Terminal and gate', 'T${f.terminal}, ${f.gate}'),
          ReceiptRow('Cabin', trip.cabin.label),
          for (var i = 0; i < trip.travellers.length; i++)
            ReceiptRow(trip.travellers[i], 'Seat ${trip.seats[i]}'),
          Divider(color: p.line, height: Space.xl),
          ReceiptRow(
            trip.cancelled ? 'Refunded' : 'Paid',
            money(trip.totalCents),
            strong: true,
          ),
          const SizedBox(height: Space.xl),
          if (canSeat) ...[
            PrimaryButton(
              key: TripKeys.seats,
              quiet: true,
              icon: Icons.airline_seat_recline_normal_rounded,
              label: 'Change seats',
              onPressed: () => _seats(trip),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (open) ...[
            PrimaryButton(
              key: TripKeys.follow,
              quiet: true,
              icon: tracked ? Icons.radar_rounded : Icons.add_rounded,
              label: tracked ? 'Following on Status' : 'Follow this flight',
              onPressed: () async {
                final notifier = ref.read(trackedProvider.notifier);
                if (!tracked) await notifier.add(f.code);
                ref.read(shellTabProvider.notifier).state = ShellTab.status;
              },
            ),
            const SizedBox(height: Space.sm),
          ],
          if (open && status.phase.index < FlightPhase.boarding.index)
            TextButton(
              key: TripKeys.cancel,
              onPressed: () => _cancel(trip),
              style: TextButton.styleFrom(
                foregroundColor: p.error,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              child: const Text('Cancel trip'),
            )
          else if (trip.cancelled && !past)
            PrimaryButton(
              key: const Key('trip-restore'),
              quiet: true,
              label: 'Book it again',
              onPressed: () async {
                await AppTiming.atLeast(
                  AppTiming.saveForm,
                  ref.read(tripsProvider.notifier).restore(trip),
                );
                if (context.mounted) showToast(context, 'Trip restored');
              },
            ),
        ],
      ),
    );
  }
}

/// The steps of a flight's day, with the one it is at marked.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip, required this.status});

  final Trip trip;
  final FlightStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = trip.flight;
    final steps = [
      (FlightPhase.scheduled, 'Booked', 'Reference ${trip.pnr}'),
      (
        FlightPhase.checkIn,
        trip.checkedIn ? 'Checked in' : 'Check-in',
        trip.checkedIn ? 'Pass ready' : 'Opens a day before',
      ),
      (
        FlightPhase.boarding,
        'Boarding',
        'Gate ${f.gate}, terminal ${f.terminal}',
      ),
      (FlightPhase.inAir, 'In the air', When.span(f.duration)),
      (FlightPhase.landed, 'Landed', 'Bags on belt ${f.belt}'),
    ];
    final at = trip.isCancelled ? -1 : status.phase.index;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: i == at ? 14 : 10,
                        height: i == at ? 14 : 10,
                        margin: EdgeInsets.only(top: i == at ? 2 : 4),
                        decoration: BoxDecoration(
                          color: i == at
                              ? p.accent
                              : i < at
                              ? p.ink
                              : p.paper,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == at
                                ? p.accent
                                : i < at
                                ? p.ink
                                : p.muted,
                            width: 1.4,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.6,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: i < at ? p.ink : p.line,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            steps[i].$2,
                            style: context.title.copyWith(
                              color: i == at
                                  ? p.accent
                                  : i < at
                                  ? p.ink
                                  : p.muted,
                            ),
                          ),
                        ),
                        Text(steps[i].$3, style: context.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

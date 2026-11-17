import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented.dart';
import '../../widgets/sky_scene.dart';
import '../actions.dart';
import '../home/home_tab.dart' show SkyBackdrop;
import '../shell/main_shell.dart';
import 'boarding_pass.dart';
import 'check_in.dart';
import 'trip_card.dart';

final tripFilterProvider = StateProvider<TripFilter>(
  (_) => TripFilter.upcoming,
);

/// Trips: the pass for the one that leaves next with its check-in, then
/// every trip under Upcoming, Past and Cancelled.
class TripsTab extends ConsumerStatefulWidget {
  const TripsTab({super.key});

  @override
  ConsumerState<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends ConsumerState<TripsTab> {
  final _scroll = ScrollController();
  final _pass = GlobalKey<FlipPassState>();
  bool _checkingIn = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static String _label(TripFilter f) => switch (f) {
    TripFilter.upcoming => 'Upcoming',
    TripFilter.past => 'Past',
    TripFilter.cancelled => 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final loading = ref.watch(tripsProvider).isLoading;
    final failed = ref.watch(tripsProvider).hasError;
    final lists = ref.watch(tripsByFilterProvider);
    final filter = ref.watch(tripFilterProvider);
    final next = ref.watch(nextTripProvider);
    final now = ref.watch(nowProvider);
    final shown = [
      for (final t in lists[filter]!)
        // The next trip is already on the page as its pass.
        if (!(filter == TripFilter.upcoming && t.id == next?.id)) t,
    ];
    final status = next == null ? null : FlightStatus.of(next.flight, now);

    return Material(
      color: p.paper,
      child: Stack(
        children: [
          SkyBackdrop(controller: _scroll),
          ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              bottom: media.padding.bottom + Sizes.tabBarReserve,
            ),
            children: [
              Stack(
                children: [
                  SkyHeader(
                    height: next == null ? Sizes.tabHeader - 40 : 190,
                    sun: const Alignment(-.8, 1),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      media.padding.top + 18,
                      Space.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Trips',
                                style: context.display.copyWith(color: p.onSky),
                              ),
                            ),
                            if (status != null)
                              StatusChip(status.line, onSky: true),
                          ],
                        ),
                        const SizedBox(height: Space.xl),
                        if (next != null) ...[
                          FlipPass(key: _pass, trip: next),
                          const SizedBox(height: Space.md),
                          _NextAction(
                            trip: next,
                            now: now,
                            busy: _checkingIn,
                            onCheckIn: () async {
                              setState(() => _checkingIn = true);
                              await checkIn(context, ref, next);
                              if (!mounted) return;
                              setState(() => _checkingIn = false);
                              _pass.currentState?.flip(toBack: true);
                            },
                            onOpen: () => openTrip(context, next),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.xl,
                  Space.gutter,
                  Space.md,
                ),
                child: Segmented<TripFilter>(
                  values: TripFilter.values,
                  value: filter,
                  label: _label,
                  caption: (f) => '${lists[f]!.length}',
                  height: 52,
                  onChanged: (f) =>
                      ref.read(tripFilterProvider.notifier).state = f,
                ),
              ),
              AnimatedSwitcher(
                duration: Motion.short,
                child: KeyedSubtree(
                  key: ValueKey(filter),
                  child: failed
                      ? EmptyState(
                          title: 'Trips could not be loaded',
                          message: 'Check your connection and try again.',
                          action: 'Try again',
                          onAction: () => ref.invalidate(tripsProvider),
                        )
                      : loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Space.gutter,
                          ),
                          child: Skeleton(height: 170),
                        )
                      : shown.isEmpty
                      ? _Empty(filter: filter, hasNext: next != null)
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.gutter,
                          ),
                          child: Column(
                            children: [
                              for (final t in shown)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: Space.md,
                                  ),
                                  child: TripCard(
                                    trip: t,
                                    onTap: () => openTrip(context, t),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Under the next pass: check in when it is open, and when it is not, say
/// why and offer the trip's page.
class _NextAction extends StatelessWidget {
  const _NextAction({
    required this.trip,
    required this.now,
    required this.busy,
    required this.onCheckIn,
    required this.onOpen,
  });

  final Trip trip;
  final DateTime now;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (trip.canCheckIn(now) || busy) {
      return PrimaryButton(
        key: const Key('trips-check-in'),
        label: 'Check in now',
        icon: Icons.how_to_reg_outlined,
        busy: busy,
        onPressed: onCheckIn,
      );
    }
    return PrimaryButton(
      key: const Key('trips-open-next'),
      quiet: true,
      label: trip.checkedIn ? 'Checked in. Trip details' : 'Trip details',
      onPressed: onOpen,
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.filter, required this.hasNext});

  final TripFilter filter;
  final bool hasNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void search() => ref.read(shellTabProvider.notifier).state = ShellTab.home;
    return switch (filter) {
      TripFilter.upcoming when hasNext => const EmptyState(
        title: 'Nothing after that',
        message: 'Your next trip is the only one booked.',
      ),
      TripFilter.upcoming => EmptyState(
        title: 'No trips booked',
        message: 'Find a flight and its boarding pass will be waiting here.',
        action: 'Search flights',
        onAction: search,
      ),
      TripFilter.past => const EmptyState(
        title: 'No past trips',
        message: 'Flights you have taken are kept here.',
      ),
      TripFilter.cancelled => const EmptyState(
        title: 'Nothing cancelled',
        message: 'Trips you cancel are kept here.',
      ),
    };
  }
}

import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/screens/status/status_card.dart';
import 'package:aloft/screens/status/status_tab.dart';
import 'package:aloft/screens/trips/boarding_pass.dart';
import 'package:aloft/screens/trips/trip_card.dart';
import 'package:aloft/screens/trips/trip_detail_screen.dart';
import 'package:aloft/screens/trips/trips_tab.dart';
import 'package:aloft/services/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUpAll(quietMotion);

  group('trips tab', () {
    testWidgets('shows the next pass with its countdown, and the three lists', (
      t,
    ) async {
      phone(t, size: const Size(390, 1500));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripsTab());
      expect(find.byType(BoardingPass), findsOneWidget);
      expect(find.text('OLYMPICSON'), findsOneWidget);
      expect(find.text('Departs in 10h 35m'), findsOneWidget);
      expect(find.text('Check in now'), findsOneWidget);
      // Upcoming: three seeded, the first of them shown as the pass.
      expect(c.read(tripsByFilterProvider)[TripFilter.upcoming], hasLength(3));
      expect(find.byType(TripCard), findsNWidgets(2));
      await t.tap(find.byKey(const ValueKey('segment-Past')));
      await t.pumpAndSettle();
      expect(find.byType(TripCard), findsNWidgets(3));
      await t.tap(find.byKey(const ValueKey('segment-Cancelled')));
      await t.pumpAndSettle();
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('checking in turns the pass to its barcode and is kept', (
      t,
    ) async {
      phone(t, size: const Size(390, 1500));
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripsTab());
      expect(find.text('NOT CHECKED IN YET'), findsNothing);
      await t.tap(find.byKey(const Key('trips-check-in')));
      await t.pumpAndSettle();
      expect(c.read(nextTripProvider)!.checkedIn, isTrue);
      expect(find.text('SCAN AT THE GATE'), findsOneWidget);
      expect(find.text('Check in now'), findsNothing);
      expect(
        store.json<Map<String, dynamic>>(
          Store.tripChanges,
        )!['t-lhr']['checkedIn'],
        isTrue,
      );
      // Tapping the pass turns it back to the front.
      await t.tap(find.byKey(const Key('pass-flip')));
      await t.pumpAndSettle();
      expect(find.text('CHECKED IN'), findsOneWidget);
    });

    testWidgets('with nothing booked it says so and points at search', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await warm(c);
      for (final trip in c.read(tripsProvider).value!) {
        await c.read(tripsProvider.notifier).cancel(trip);
      }
      await pumpScreen(t, c, const TripsTab());
      expect(find.byType(BoardingPass), findsNothing);
      expect(find.text('No trips booked'), findsOneWidget);
      expect(find.text('Search flights'), findsOneWidget);
    });
  });

  group('a trip', () {
    testWidgets('shows its day, its details and what can be done', (t) async {
      phone(t, size: const Size(390, 1900));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripDetailScreen(tripId: 't-lhr'));
      expect(find.text('Lagos to London'), findsOneWidget);
      expect(find.text('Check-in open'), findsOneWidget);
      expect(find.text('Reference K7QM4X'), findsOneWidget);
      expect(find.text('Seat 24A'), findsOneWidget);
      expect(find.byKey(TripKeys.checkIn), findsOneWidget);
      expect(find.byKey(TripKeys.seats), findsOneWidget);
      expect(find.byKey(TripKeys.cancel), findsOneWidget);
    });

    testWidgets('one that is far off says when check-in opens', (t) async {
      phone(t, size: const Size(390, 1900));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripDetailScreen(tripId: 't-nbo'));
      expect(find.byKey(TripKeys.checkIn), findsNothing);
      expect(
        find.textContaining('Check-in opens 11d 0h from now'),
        findsOneWidget,
      );
      // Two travellers, two seats.
      expect(find.text('Ada Okafor'), findsOneWidget);
      expect(find.text('Seat 6C'), findsOneWidget);
    });

    testWidgets('cancelling asks first, moves it to Cancelled, and undoes', (
      t,
    ) async {
      phone(t, size: const Size(390, 1900));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripDetailScreen(tripId: 't-nbo'));
      await t.tap(find.byKey(TripKeys.cancel));
      await t.pumpAndSettle();
      expect(find.text('Cancel this trip?'), findsOneWidget);
      await t.tap(find.byKey(const Key('confirm-remove')));
      await t.pumpAndSettle();
      expect(c.read(tripProvider('t-nbo'))!.cancelled, isTrue);
      expect(find.text('You cancelled this trip'), findsOneWidget);
      expect(find.text('Refunded'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(tripProvider('t-nbo'))!.cancelled, isFalse);
    });

    testWidgets('a past trip offers nothing to change', (t) async {
      phone(t, size: const Size(390, 1900));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripDetailScreen(tripId: 't-acc'));
      expect(find.text('Landed'), findsWidgets);
      expect(find.byKey(TripKeys.cancel), findsNothing);
      expect(find.byKey(TripKeys.seats), findsNothing);
      expect(find.byKey(TripKeys.checkIn), findsNothing);
    });

    testWidgets('changing seats is saved', (t) async {
      phone(t, size: const Size(390, 1900));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TripDetailScreen(tripId: 't-lhr'));
      await t.tap(find.byKey(TripKeys.seats));
      await t.pumpAndSettle();
      // The seat already held shows as ours, not as taken.
      expect(
        t.getSemantics(find.byKey(const Key('seat-24A'))).label,
        isNot(contains('taken')),
      );
      await t.tap(find.byKey(const Key('seat-confirm')));
      await t.pumpAndSettle();
      expect(c.read(tripProvider('t-lhr'))!.seats, ['24A']);
    });
  });

  group('status', () {
    testWidgets('follows the seeded flights, each in its own state', (t) async {
      phone(t, size: const Size(390, 2200));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const StatusTab());
      expect(find.text('Following 3'), findsOneWidget);
      expect(find.byType(StatusCard), findsNWidgets(3));
      expect(find.text('In the air'), findsOneWidget);
      expect(find.text('Boarding'), findsOneWidget);
      expect(find.text('Delayed 45m'), findsOneWidget);
      expect(find.text('Lands in 4h 55m'), findsOneWidget);
    });

    testWidgets('looking up: nothing typed, not found, found and followed', (
      t,
    ) async {
      phone(t, size: const Size(390, 2600));
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const StatusTab());
      await t.tap(find.byKey(StatusKeys.find));
      await t.pumpAndSettle();
      expect(
        find.text('Enter a flight number, such as HC 318.'),
        findsOneWidget,
      );

      await t.enterText(find.byKey(StatusKeys.field), 'zz 999');
      await t.tap(find.byKey(StatusKeys.find));
      await t.pumpAndSettle();
      expect(
        find.text('No flight ZZ 999 today. Check the number on your ticket.'),
        findsOneWidget,
      );

      // Typed loosely, it is still found: a cancelled one.
      await t.enterText(find.byKey(StatusKeys.field), 'sv409');
      await t.tap(find.byKey(StatusKeys.find));
      await t.pumpAndSettle();
      expect(find.byType(StatusCard), findsNWidgets(4));
      expect(find.text('This flight will not operate'), findsOneWidget);
      await t.tap(find.byKey(StatusKeys.follow));
      await t.pumpAndSettle();
      expect(c.read(trackedProvider).first, 'SV409');
      expect(store.strings(Store.tracked), contains('SV409'));
      expect(find.text('Following 4'), findsOneWidget);
    });

    testWidgets('unfollowing can be undone, back in its place', (t) async {
      phone(t, size: const Size(390, 2200));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const StatusTab());
      final before = [...c.read(trackedProvider)];
      await t.tap(find.byKey(const Key('unfollow-KS204')));
      await t.pumpAndSettle();
      expect(c.read(trackedProvider), isNot(contains('KS204')));
      expect(find.text('Stopped following KS 204'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(trackedProvider), before);
    });

    testWidgets('with nothing followed it explains what the tab is for', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.tracked: <String>[]},
      );
      await pumpScreen(t, c, const StatusTab());
      expect(find.text('Not following any flights'), findsOneWidget);
    });

    testWidgets('your own flight can be found by its number', (t) async {
      phone(t, size: const Size(390, 2600));
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const StatusTab());
      await t.enterText(find.byKey(StatusKeys.field), 'AL 482');
      await t.tap(find.byKey(StatusKeys.find));
      await t.pumpAndSettle();
      expect(find.text('Check-in open'), findsOneWidget);
    });
  });
}

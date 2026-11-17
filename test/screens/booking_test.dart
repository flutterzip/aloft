import 'package:aloft/models/flight.dart';
import 'package:aloft/providers/account_providers.dart';
import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/screens/booking/booking_screen.dart';
import 'package:aloft/screens/booking/confirmed_screen.dart';
import 'package:aloft/screens/profile/traveller_sheet.dart';
import 'package:aloft/services/flight_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aloft/kit/kit.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUpAll(quietMotion);
  final day = DateTime(2026, 11, 17);
  List<Flight> timetable(SearchQuery q) => DemoFlightRepository(
    seed,
    clock: () => testNow,
    seedStamp: testNow,
  ).timetable(q);

  Future<void> pay(WidgetTester t) async {
    await t.tap(find.byType(PayButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    await t.pumpAndSettle();
  }

  testWidgets('one traveller, one flight: review shows the fare and books it', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
    final flight = timetable(q).first;
    await pumpScreen(t, c, BookingScreen(query: q, flights: [flight]));
    expect(find.text('Review and pay'), findsOneWidget);
    expect(find.text('WHO IS FLYING'), findsOneWidget);
    expect(find.textContaining('Visa ending 4242'), findsOneWidget);
    final before = c.read(tripsProvider).value!.length;
    await pay(t);
    expect(find.byType(ConfirmedScreen), findsOneWidget);
    expect(find.text('You are going to London'), findsOneWidget);
    final trips = c.read(tripsProvider).value!;
    expect(trips.length, before + 1);
    final booked = trips.firstWhere((x) => x.flight.id == flight.id);
    expect(booked.travellers, ['Olympicson']);
    expect(booked.totalCents, flight.priceCents);
    expect(booked.seats, hasLength(1));
    expect(find.textContaining(booked.pnr), findsWidgets);
  });

  testWidgets('a return books two trips under one reference', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final q = SearchQuery(
      from: 'LOS',
      to: 'LHR',
      date: day,
      returnDate: DateTime(2026, 11, 24),
      adults: 2,
    );
    final out = timetable(q).first;
    final back = timetable(q.back).first;
    await pumpScreen(t, c, BookingScreen(query: q, flights: [out, back]));
    expect(find.text('FLIGHT OUT'), findsOneWidget);
    expect(find.text('FLIGHT BACK'), findsOneWidget);
    expect(find.text('WHO IS FLYING, CHOOSE 2'), findsOneWidget);
    await pay(t);
    expect(find.byType(ConfirmedScreen), findsOneWidget);
    final booked = [
      for (final x in c.read(tripsProvider).value!)
        if (x.flight.id == out.id || x.flight.id == back.id) x,
    ];
    expect(booked, hasLength(2));
    expect(booked[0].pnr, booked[1].pnr);
    expect(booked[0].travellers, ['Olympicson', 'Ada Okafor']);
    expect(booked[0].seats, hasLength(2));
  });

  testWidgets('too few travellers: the button says so and nothing is booked', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final q = SearchQuery(from: 'LOS', to: 'LHR', date: day, adults: 2);
    await pumpScreen(
      t,
      c,
      BookingScreen(query: q, flights: [timetable(q).first]),
    );
    // Take Ada off the booking.
    await tapVisible(t, find.byKey(const Key('booking-traveller-ada')));
    final before = c.read(tripsProvider).value!.length;
    await pay(t);
    expect(
      find.text('Choose 1 more traveller to book 2 seats.'),
      findsOneWidget,
    );
    expect(find.byType(ConfirmedScreen), findsNothing);
    expect(c.read(tripsProvider).value!.length, before);
  });

  testWidgets('the seeded declining card is refused, by name', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final bad = seed.cards.firstWhere(
      (x) => x.last4 == seed.decliningCardLast4,
    );
    await warm(c);
    await c.read(defaultCardIdProvider.notifier).choose(bad.id);
    final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
    await pumpScreen(
      t,
      c,
      BookingScreen(query: q, flights: [timetable(q).first]),
    );
    final before = c.read(tripsProvider).value!.length;
    await pay(t);
    expect(
      find.textContaining('was declined. Nothing was charged.'),
      findsOneWidget,
    );
    expect(find.byType(ConfirmedScreen), findsNothing);
    expect(c.read(tripsProvider).value!.length, before);
  });

  testWidgets('seats can be chosen, one per traveller', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final q = SearchQuery(from: 'LOS', to: 'LHR', date: day, adults: 2);
    final flight = timetable(q).first;
    await pumpScreen(t, c, BookingScreen(query: q, flights: [flight]));
    await tapVisible(t, find.byKey(const Key('booking-seats-0')));
    expect(find.textContaining('Choose seats'), findsOneWidget);
    // Two free seats in the first row of the cabin that are not ours.
    final free = [
      for (final s in [
        '18A',
        '18B',
        '18C',
        '18D',
        '18E',
        '18F',
        '19A',
        '19B',
        '19C',
      ])
        if (t
                .widget<Semantics>(
                  find
                      .ancestor(
                        of: find.byKey(Key('seat-$s')),
                        matching: find.byType(Semantics),
                      )
                      .first,
                )
                .properties
                .enabled ==
            true)
          s,
    ];
    expect(free.length, greaterThanOrEqualTo(2));
    await tapVisible(t, find.byKey(Key('seat-${free[0]}')));
    await tapVisible(t, find.byKey(Key('seat-${free[1]}')));
    await t.tap(find.byKey(const Key('seat-confirm')));
    await t.pumpAndSettle();
    expect(find.text('Seats ${free[0]}, ${free[1]}'), findsOneWidget);
    await pay(t);
    final booked = c
        .read(tripsProvider)
        .value!
        .firstWhere((x) => x.flight.id == flight.id);
    expect(booked.seats, [free[0], free[1]]);
  });

  testWidgets('a traveller added here is saved and joins the booking', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
    await pumpScreen(
      t,
      c,
      BookingScreen(query: q, flights: [timetable(q).first]),
    );
    await tapVisible(t, find.byKey(BookingKeys.addTraveller));
    await t.tap(find.byKey(TravellerKeys.save));
    await t.pumpAndSettle();
    expect(
      find.text('Enter the name as it is on the passport.'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(TravellerKeys.name), 'Zainab Bello');
    await t.enterText(find.byKey(TravellerKeys.born), '1990');
    await t.enterText(find.byKey(TravellerKeys.nationality), 'Nigeria');
    await t.tap(find.byKey(TravellerKeys.save));
    await t.pumpAndSettle();
    expect(
      c.read(travellersProvider).value!.map((x) => x.name),
      contains('Zainab Bello'),
    );
    await pay(t);
    // One seat: the newest choice took it.
    expect(
      c
          .read(tripsProvider)
          .value!
          .any((x) => x.travellers.single == 'Zainab Bello'),
      isTrue,
    );
  });
}

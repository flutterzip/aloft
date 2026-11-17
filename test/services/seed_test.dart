import 'dart:math';

import 'package:aloft/models/airport.dart';
import 'package:aloft/models/flight.dart';
import 'package:aloft/models/trip.dart';
import 'package:aloft/services/flight_repository.dart';
import 'package:aloft/services/store.dart';
import 'package:aloft/services/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  DemoFlightRepository flights({DateTime? now}) => DemoFlightRepository(
    seed,
    clock: () => now ?? testNow,
    seedStamp: testNow,
    latency: Duration.zero,
  );

  group('seed', () {
    test('parses, and the product name is filled in', () {
      expect(seed.world.airports.length, greaterThanOrEqualTo(15));
      expect(seed.world.airline('AL').name, 'Aloft Air');
      expect(seed.profile.name, 'Olympicson');
      expect(seed.profile.email, 'hello@flutterzip.com');
    });

    test('every code a record uses is an airport or airline that exists', () {
      final airlines = {for (final a in seed.world.airlines) a.code};
      for (final j in [...seed.trips, ...seed.live]) {
        expect(seed.world.maybeAirport(j['from'] as String), isNotNull);
        expect(seed.world.maybeAirport(j['to'] as String), isNotNull);
        expect(airlines, contains(j['airline']));
      }
      for (final (from, to) in seed.popular) {
        expect(seed.world.maybeAirport(from), isNotNull);
        expect(seed.world.maybeAirport(to), isNotNull);
      }
      for (final h in seed.hubs) {
        expect(seed.world.maybeAirport(h), isNotNull);
      }
      expect(seed.world.maybeAirport(seed.homeAirport), isNotNull);
    });

    test('a first launch meets every state a trip and a flight can be in', () {
      final trips = [for (final j in seed.trips) Trip.fromSeed(j, testNow)];
      final next =
          trips.where((t) => !t.isCancelled && !t.isPast(testNow)).toList()
            ..sort((a, b) => a.flight.depart.compareTo(b.flight.depart));
      expect(next.first.canCheckIn(testNow), isTrue);
      expect(trips.where((t) => t.isPast(testNow)), isNotEmpty);
      expect(trips.where((t) => t.cancelled), isNotEmpty);
      expect(trips.any((t) => t.travellers.length > 1), isTrue);

      final phases = {
        for (final j in seed.live)
          FlightStatus.of(Flight.fromSeed(j, testNow), testNow).phase,
      };
      expect(
        phases,
        containsAll([
          FlightPhase.inAir,
          FlightPhase.boarding,
          FlightPhase.landed,
          FlightPhase.cancelled,
        ]),
      );
      expect(seed.live.any((j) => (j['delayMin'] ?? 0) as int >= 15), isTrue);
      expect(seed.cards.any((c) => c.last4 == seed.decliningCardLast4), isTrue);
    });
  });

  group('timetable', () {
    final day = DateTime(2026, 11, 17);

    test('the same route and day always give the same flights', () {
      final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
      final a = flights().timetable(q);
      final b = flights().timetable(q);
      expect([for (final f in a) f.id], [for (final f in b) f.id]);
      expect(
        [for (final f in a) f.priceCents],
        [for (final f in b) f.priceCents],
      );
      expect(a.length, inInclusiveRange(4, 6));
    });

    test(
      'a flight takes about as long as its distance, and lands after it leaves',
      () {
        for (final f in flights().timetable(
          SearchQuery(from: 'LOS', to: 'LHR', date: day),
        )) {
          expect(f.arrive.isAfter(f.depart), isTrue);
          if (f.nonStop) {
            expect(f.duration.inMinutes, inInclusiveRange(380, 420));
          }
          expect(f.priceCents % 100, 0);
          expect(f.priceCents, greaterThan(20000));
        }
      },
    );

    test('a route too far for one hop only has flights with a stop', () {
      final list = flights().timetable(
        SearchQuery(from: 'LOS', to: 'SYD', date: day),
      );
      expect(list, isNotEmpty);
      expect(list.every((f) => !f.nonStop), isTrue);
      expect(list.every((f) => seed.hubs.contains(f.via)), isTrue);
    });

    test('a short hop is always non-stop', () {
      final list = flights().timetable(
        SearchQuery(from: 'ACC', to: 'LOS', date: day),
      );
      expect(list.every((f) => f.nonStop), isTrue);
    });

    test('a dearer cabin costs more for the same flight', () {
      int fare(Cabin c) => flights()
          .timetable(SearchQuery(from: 'LOS', to: 'LHR', date: day, cabin: c))
          .first
          .priceCents;
      expect(fare(Cabin.premium), greaterThan(fare(Cabin.economy)));
      expect(fare(Cabin.first), greaterThan(fare(Cabin.business)));
    });

    test(
      'search is cheapest first and leaves out flights already gone',
      () async {
        final repo = flights(now: DateTime.utc(2026, 11, 17, 13));
        final list = await repo.search(
          SearchQuery(from: 'LOS', to: 'LHR', date: day),
        );
        final all = repo.timetable(
          SearchQuery(from: 'LOS', to: 'LHR', date: day),
        );
        expect(list.length, lessThan(all.length));
        for (var i = 1; i < list.length; i++) {
          expect(
            list[i].priceCents,
            greaterThanOrEqualTo(list[i - 1].priceCents),
          );
        }
        expect(
          list.every((f) => f.depart.isAfter(DateTime.utc(2026, 11, 17, 13))),
          isTrue,
        );
      },
    );

    test(
      'fares give the lowest price of each day that still has flights',
      () async {
        final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
        final fares = await flights().fares(q, [
          day,
          day.add(const Duration(days: 1)),
        ]);
        expect(fares.length, 2);
        final list = await flights().search(q);
        expect(fares[day], list.first.priceCents);
      },
    );

    test('popular routes carry the cheapest flight a week out', () async {
      final deals = await flights().popular();
      expect(deals.length, seed.popular.length);
      expect(deals.first.flight.from, seed.popular.first.$1);
    });
  });

  group('trips', () {
    Future<(DemoTripRepository, Store)> repo() async {
      SharedPreferences.setMockInitialValues({});
      final store = Store(await SharedPreferences.getInstance());
      return (
        DemoTripRepository(
          seed,
          store,
          seedStamp: testNow,
          clock: () => testNow,
          latency: Duration.zero,
          random: Random(7),
        ),
        store,
      );
    }

    final flight = Flight(
      id: 'AL100-2026-11-17',
      airline: 'AL',
      number: '100',
      from: 'LOS',
      to: 'LHR',
      depart: DateTime.utc(2026, 11, 17, 9),
      arrive: DateTime.utc(2026, 11, 17, 15, 45),
      priceCents: 45000,
    );

    test('seeded trips come back soonest first', () async {
      final (r, _) = await repo();
      final trips = await r.trips();
      expect(trips.length, seed.trips.length);
      for (var i = 1; i < trips.length; i++) {
        expect(
          trips[i].flight.depart.isBefore(trips[i - 1].flight.depart),
          isFalse,
        );
      }
    });

    test('booking a return makes two trips under one reference', () async {
      final (r, _) = await repo();
      final booked = await r.book(
        legs: [
          (flight: flight, seats: ['20A', '20B']),
          (flight: flight, seats: ['21A', '21B']),
        ],
        cabin: Cabin.economy,
        travellers: ['Olympicson', 'Ada Okafor'],
        card: seed.cards.first,
      );
      expect(booked, hasLength(2));
      expect(booked[0].pnr, booked[1].pnr);
      expect(booked[0].pnr, matches(RegExp(r'^[A-Z2-9]{6}$')));
      expect(booked[0].id, isNot(booked[1].id));
      expect(booked[0].totalCents, 90000);
      expect((await r.trips()).length, seed.trips.length + 2);
    });

    test(
      'the seeded declining card is refused and nothing is booked',
      () async {
        final (r, _) = await repo();
        final bad = seed.cards.firstWhere(
          (c) => c.last4 == seed.decliningCardLast4,
        );
        await expectLater(
          r.book(
            legs: [
              (flight: flight, seats: ['20A']),
            ],
            cabin: Cabin.economy,
            travellers: ['Olympicson'],
            card: bad,
          ),
          throwsA(isA<PaymentDeclined>()),
        );
        expect((await r.trips()).length, seed.trips.length);
      },
    );

    test(
      'a change to a seeded trip is kept, and a booked one is replaced',
      () async {
        final (r, store) = await repo();
        final seeded = (await r.trips()).firstWhere((t) => t.id == 't-lhr');
        await r.save(seeded.copyWith(checkedIn: true, seats: ['2A']));
        final again = (await r.trips()).firstWhere((t) => t.id == 't-lhr');
        expect(again.checkedIn, isTrue);
        expect(again.seats, ['2A']);
        expect(
          store.json<Map<String, dynamic>>(Store.tripChanges),
          contains('t-lhr'),
        );

        final booked = (await r.book(
          legs: [
            (flight: flight, seats: ['20A']),
          ],
          cabin: Cabin.economy,
          travellers: ['Olympicson'],
          card: seed.cards.first,
        )).single;
        await r.save(booked.copyWith(cancelled: true));
        final after = (await r.trips()).firstWhere((t) => t.id == booked.id);
        expect(after.cancelled, isTrue);
        expect((await r.trips()).where((t) => t.id == booked.id), hasLength(1));
      },
    );
  });
}

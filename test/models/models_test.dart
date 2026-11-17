import 'package:aloft/models/airport.dart';
import 'package:aloft/models/flight.dart';
import 'package:aloft/models/money.dart';
import 'package:aloft/models/trip.dart';
import 'package:aloft/models/when.dart';
import 'package:flutter_test/flutter_test.dart';

Flight flight({
  int inMin = 600,
  int minutes = 400,
  int delay = 0,
  bool off = false,
  DateTime? now,
}) {
  final depart = (now ?? DateTime.utc(2026, 11, 10, 12)).add(
    Duration(minutes: inMin),
  );
  return Flight(
    id: 'AL482',
    airline: 'AL',
    number: '482',
    from: 'LOS',
    to: 'LHR',
    depart: depart,
    arrive: depart.add(Duration(minutes: minutes)),
    priceCents: 49000,
    delayMin: delay,
    cancelled: off,
  );
}

void main() {
  final now = DateTime.utc(2026, 11, 10, 12);

  test('money is written from cents', () {
    expect(money(49000), r'$490');
    expect(money(164000), r'$1,640');
    expect(money(1250), r'$12.50');
    expect(money(-500), r'-$5');
  });

  test('dates and spans read the way the app writes them', () {
    final d = DateTime(2026, 9, 4, 6, 5);
    expect(When.time(d), '6:05 AM');
    expect(When.time(DateTime(2026, 9, 4, 0, 30)), '12:30 AM');
    expect(When.time(DateTime(2026, 9, 4, 13, 30)), '1:30 PM');
    expect(When.day(d), 'Fri, 4 Sep');
    expect(When.span(const Duration(minutes: 405)), '6h 45m');
    expect(When.span(const Duration(minutes: 45)), '45m');
    expect(When.span(const Duration(days: 12, hours: 3)), '12d 3h');
    expect(When.iso(d), '2026-09-04');
  });

  group('a flight\'s phase is derived from its times', () {
    test('far off, it is scheduled', () {
      final s = FlightStatus.of(flight(inMin: 3 * 24 * 60), now);
      expect(s.phase, FlightPhase.scheduled);
      expect(s.line, 'Departs in 3d 0h');
    });
    test('inside a day, check-in is open', () {
      final s = FlightStatus.of(flight(inMin: 635), now);
      expect(s.phase, FlightPhase.checkIn);
      expect(s.line, 'Departs in 10h 35m');
    });
    test('inside 45 minutes, it is boarding', () {
      final s = FlightStatus.of(flight(inMin: 28), now);
      expect(s.phase, FlightPhase.boarding);
      expect(s.live, isTrue);
    });
    test('after departure the plane is part way along', () {
      final s = FlightStatus.of(flight(inMin: -100, minutes: 400), now);
      expect(s.phase, FlightPhase.inAir);
      expect(s.progress, closeTo(.25, .001));
      expect(s.line, 'Lands in 5h 00m');
    });
    test('after arrival it has landed', () {
      final s = FlightStatus.of(flight(inMin: -500, minutes: 400), now);
      expect(s.phase, FlightPhase.landed);
      expect(s.progress, 1);
    });
    test('a delay moves both ends and is named', () {
      final f = flight(inMin: 95, delay: 45);
      final s = FlightStatus.of(f, now);
      expect(s.delayed, isTrue);
      expect(s.headline, 'Delayed 45m');
      expect(s.untilDepart.inMinutes, 140);
      expect(f.actualArrive.difference(f.arrive).inMinutes, 45);
    });
    test('cancelled wins over everything', () {
      final s = FlightStatus.of(flight(inMin: -10, off: true), now);
      expect(s.phase, FlightPhase.cancelled);
      expect(s.headline, 'Cancelled');
    });
  });

  test('gate, terminal and belt are fixed per flight', () {
    expect(flight().gate, flight().gate);
    expect(flight().gate, matches(RegExp(r'^[A-E]\d{1,2}$')));
  });

  group('trip', () {
    Trip trip(Flight f, {bool checkedIn = false, bool cancelled = false}) =>
        Trip(
          id: 't',
          pnr: 'K7QM4X',
          flight: f,
          cabin: Cabin.economy,
          seats: const ['24A'],
          travellers: const ['Olympicson'],
          totalCents: 49000,
          bookedAt: now,
          checkedIn: checkedIn,
          cancelled: cancelled,
        );

    test('check-in is open from a day before until boarding', () {
      expect(trip(flight(inMin: 3000)).canCheckIn(now), isFalse);
      expect(trip(flight(inMin: 635)).canCheckIn(now), isTrue);
      expect(trip(flight(inMin: 30)).canCheckIn(now), isFalse);
      expect(
        trip(flight(inMin: 635), checkedIn: true).canCheckIn(now),
        isFalse,
      );
      expect(
        trip(flight(inMin: 635), cancelled: true).canCheckIn(now),
        isFalse,
      );
    });

    test('survives a round trip through JSON', () {
      final t = Trip.fromJson(trip(flight(delay: 15)).toJson());
      expect(t.pnr, 'K7QM4X');
      expect(t.flight.delayMin, 15);
      expect(t.flight.depart, flight().depart);
      expect(t.seats, ['24A']);
    });
  });

  group('seat map', () {
    test('is the same every time for the same flight', () {
      final a = SeatMap('AL482-2026-11-17', Cabin.economy);
      final b = SeatMap('AL482-2026-11-17', Cabin.economy);
      for (var r = a.firstRow; r < a.firstRow + a.rowCount; r++) {
        for (final l in a.letters) {
          expect(a.taken('$r$l'), b.taken('$r$l'));
        }
      }
    });

    test('suggests free seats, one per traveller, in one row if it can', () {
      final map = SeatMap('AL482-2026-11-17', Cabin.economy);
      final seats = map.suggest(3);
      expect(seats, hasLength(3));
      expect(seats.toSet(), hasLength(3));
      for (final s in seats) {
        expect(map.taken(s), isFalse);
      }
    });

    test('never shows a seat on this booking as taken', () {
      final all = SeatMap('X', Cabin.economy);
      final taken = [
        for (var r = all.firstRow; r < all.firstRow + all.rowCount; r++)
          for (final l in all.letters)
            if (all.taken('$r$l')) '$r$l',
      ];
      expect(taken, isNotEmpty);
      expect(
        SeatMap('X', Cabin.economy, mine: [taken.first]).taken(taken.first),
        isFalse,
      );
    });

    test('business is two and two', () {
      expect(SeatMap('X', Cabin.business).letters, ['A', 'C', 'D', 'F']);
    });
  });

  test('a search survives a round trip through JSON, and turns round', () {
    final q = SearchQuery(
      from: 'LOS',
      to: 'LHR',
      date: DateTime(2026, 11, 17),
      returnDate: DateTime(2026, 11, 24),
      adults: 2,
      cabin: Cabin.business,
    );
    final r = SearchQuery.fromJson(q.toJson());
    expect(
      (r.from, r.to, r.adults, r.cabin),
      ('LOS', 'LHR', 2, Cabin.business),
    );
    expect(r.returnDate, DateTime(2026, 11, 24));
    expect(
      (r.back.from, r.back.to, r.back.date),
      ('LHR', 'LOS', DateTime(2026, 11, 24)),
    );
    expect(r.back.roundTrip, isFalse);
    expect(q.copyWith(oneWay: true).roundTrip, isFalse);
  });

  test('distance between airports is the great circle', () {
    const los = Airport(
      code: 'LOS',
      city: 'Lagos',
      name: '',
      country: 'Nigeria',
      lat: 6.577,
      lon: 3.321,
      utcOffsetMin: 60,
    );
    const lhr = Airport(
      code: 'LHR',
      city: 'London',
      name: '',
      country: 'UK',
      lat: 51.47,
      lon: -.454,
      utcOffsetMin: 0,
    );
    expect(los.distanceTo(lhr), closeTo(5000, 60));
    expect(los.local(DateTime.utc(2026, 1, 1, 12)).hour, 13);
    expect(los.matches('lag'), isTrue);
    expect(los.matches('xyz'), isFalse);
  });
}

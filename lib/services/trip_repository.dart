import 'dart:math';

import '../config/app_timing.dart';
import '../models/account.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../models/ids.dart';
import '../models/trip.dart';
import 'seed.dart';
import 'store.dart';

/// The card was refused. The booking was not made.
class PaymentDeclined implements Exception {
  const PaymentDeclined();
}

/// One leg being booked: the flight and the seats picked on it.
typedef Leg = ({Flight flight, List<String> seats});

/// Booked trips. Async throughout, so a backend drops in without touching a
/// widget.
abstract interface class TripRepository {
  Future<List<Trip>> trips();

  /// Pays for and books [legs] under one booking reference. Throws
  /// [PaymentDeclined] when the card is refused.
  Future<List<Trip>> book({
    required List<Leg> legs,
    required Cabin cabin,
    required List<String> travellers,
    required PaymentCard card,
  });

  /// Saves a change to a trip: new seats, a check-in, a cancellation.
  Future<Trip> save(Trip trip);
}

/// The seeded trips, with their times counted from this launch so there is
/// always one about to leave, plus whatever was booked on this device.
class DemoTripRepository implements TripRepository {
  DemoTripRepository(
    this._seed,
    this._store, {
    required DateTime seedStamp,
    required DateTime Function() clock,
    Duration? latency,
    Random? random,
  }) : _stamp = seedStamp,
       _clock = clock,
       _latency = latency,
       _random = random ?? Random();

  final Seed _seed;
  final Store _store;
  final DateTime _stamp;
  final DateTime Function() _clock;
  final Duration? _latency;
  final Random _random;

  Map<String, dynamic> get _changes =>
      _store.json<Map<String, dynamic>>(Store.tripChanges) ?? {};

  List<Trip> get _placed => [
    for (final j in _store.json<List<dynamic>>(Store.placedTrips) ?? const [])
      Trip.fromJson(j as Map<String, dynamic>),
  ];

  @override
  Future<List<Trip>> trips() async {
    final changes = _changes;
    return [
      ..._placed,
      for (final j in _seed.trips)
        _changed(Trip.fromSeed(j, _stamp), changes[j['id']]),
    ]..sort((a, b) => a.flight.depart.compareTo(b.flight.depart));
  }

  static Trip _changed(Trip trip, Object? change) {
    if (change is! Map<String, dynamic>) return trip;
    return trip.copyWith(
      seats: (change['seats'] as List?)?.cast<String>(),
      checkedIn: change['checkedIn'] as bool?,
      cancelled: change['cancelled'] as bool?,
    );
  }

  String _reference() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return [
      for (var i = 0; i < 6; i++) letters[_random.nextInt(letters.length)],
    ].join();
  }

  @override
  Future<List<Trip>> book({
    required List<Leg> legs,
    required Cabin cabin,
    required List<String> travellers,
    required PaymentCard card,
  }) async {
    await AppTiming.wait(_latency ?? AppTiming.payment);
    if (card.last4 == _seed.decliningCardLast4) throw const PaymentDeclined();
    final pnr = _reference();
    final booked = [
      for (final leg in legs)
        Trip(
          id: Ids.next('t'),
          pnr: pnr,
          flight: leg.flight,
          cabin: cabin,
          seats: leg.seats,
          travellers: travellers,
          totalCents: leg.flight.priceCents * travellers.length,
          bookedAt: _clock(),
        ),
    ];
    await _store.setJson(Store.placedTrips, [
      for (final t in [..._placed, ...booked]) t.toJson(),
    ]);
    return booked;
  }

  @override
  Future<Trip> save(Trip trip) async {
    final placed = _placed;
    if (placed.any((t) => t.id == trip.id)) {
      await _store.setJson(Store.placedTrips, [
        for (final t in placed) (t.id == trip.id ? trip : t).toJson(),
      ]);
    } else {
      // A seeded trip: only what changed is kept, because its times are
      // counted afresh from each launch.
      await _store.setJson(Store.tripChanges, {
        ..._changes,
        trip.id: {
          'seats': trip.seats,
          'checkedIn': trip.checkedIn,
          'cancelled': trip.cancelled,
        },
      });
    }
    return trip;
  }
}

// A network implementation:
//
// class RemoteTripRepository implements TripRepository {
//   RemoteTripRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<List<Trip>> trips() async =>
//       [for (final j in (await _dio.get('/me/trips')).data as List) Trip.fromJson(j)];
//
//   // A real card is charged through the payment provider's SDK; send its
//   // token, never the card.
//   ...
// }

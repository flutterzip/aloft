import '../config/app_timing.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../models/when.dart';
import 'seed.dart';

/// A route offered on the home tab, with the lowest fare found for it.
class RouteDeal {
  const RouteDeal({required this.flight});

  /// The cheapest flight on the route a week from now, non-stop if the
  /// route has one.
  final Flight flight;
}

/// Schedules, fares and live flights. Async throughout, so a network
/// implementation drops in without touching a widget.
abstract interface class FlightRepository {
  Future<World> world();
  Future<List<RouteDeal>> popular();

  /// Flights for the outbound leg of [query], cheapest first.
  Future<List<Flight>> search(SearchQuery query);

  /// The lowest fare on each of [days], for the date strip. A day with no
  /// flights left is absent.
  Future<Map<DateTime, int>> fares(SearchQuery query, List<DateTime> days);

  /// Flights that can be followed today.
  Future<List<Flight>> live();
}

/// Makes a believable timetable for any pair of airports on any day, from
/// the distance between them. The same route and day always give the same
/// flights, so a result opened twice has not changed.
class DemoFlightRepository implements FlightRepository {
  DemoFlightRepository(
    this._seed, {
    required DateTime Function() clock,
    required DateTime seedStamp,
    Duration? latency,
  }) : _clock = clock,
       _stamp = seedStamp,
       _latency = latency;

  final Seed _seed;
  final DateTime Function() _clock;
  final DateTime _stamp;
  final Duration? _latency;

  /// The longest hop flown without a stop, in kilometres.
  static const longestNonStop = 9500.0;

  static const _slots = [370, 525, 680, 845, 1060, 1275, 1410];

  @override
  Future<World> world() async => _seed.world;

  @override
  Future<List<RouteDeal>> popular() async {
    final day = When.dateOnly(_clock()).add(const Duration(days: 7));
    Flight cheapest(Iterable<Flight> list) =>
        list.reduce((a, b) => a.priceCents <= b.priceCents ? a : b);
    return [
      for (final (from, to) in _seed.popular)
        RouteDeal(
          flight: () {
            final all = timetable(SearchQuery(from: from, to: to, date: day));
            final direct = all.where((f) => f.nonStop);
            // The fare shown is for flying straight there when that exists.
            return cheapest(direct.isEmpty ? all : direct);
          }(),
        ),
    ];
  }

  @override
  Future<List<Flight>> search(SearchQuery query) async {
    await AppTiming.wait(_latency ?? AppTiming.search);
    final earliest = _clock().add(FlightStatus.boardingOpens);
    return [
      for (final f in timetable(query))
        if (f.depart.isAfter(earliest)) f,
    ]..sort((a, b) => a.priceCents.compareTo(b.priceCents));
  }

  @override
  Future<Map<DateTime, int>> fares(
    SearchQuery query,
    List<DateTime> days,
  ) async {
    final earliest = _clock().add(FlightStatus.boardingOpens);
    final out = <DateTime, int>{};
    for (final day in days) {
      final prices = [
        for (final f in timetable(query.copyWith(date: day)))
          if (f.depart.isAfter(earliest)) f.priceCents,
      ];
      if (prices.isNotEmpty) {
        out[When.dateOnly(day)] = prices.reduce((a, b) => a < b ? a : b);
      }
    }
    return out;
  }

  @override
  Future<List<Flight>> live() async => [
    for (final j in _seed.live) Flight.fromSeed(j, _stamp),
  ];

  static int _minutes(double km) => ((35 + km / 830 * 60) / 5).round() * 5;

  /// Every flight on the route that day, in departure order.
  List<Flight> timetable(SearchQuery q) {
    final world = _seed.world;
    final from = world.airport(q.from);
    final to = world.airport(q.to);
    final km = from.distanceTo(to);
    final day = When.iso(q.date);
    final route = '${q.from}${q.to}';
    final dayFactor = 86 + stableHash('$route$day') % 37;

    String? hub;
    var viaKm = double.infinity;
    for (final code in _seed.hubs) {
      if (code == q.from || code == q.to) continue;
      final h = world.airport(code);
      final total = from.distanceTo(h) + h.distanceTo(to);
      if (total < viaKm) {
        viaKm = total;
        hub = code;
      }
    }

    final count = 4 + stableHash('n$route$day') % 3;
    final flights = <Flight>[];
    for (var i = 0; i < count; i++) {
      final h = stableHash('$route$day$i');
      final connects =
          hub != null && (km > longestNonStop || (km > 2500 && i % 3 == 1));
      final localMinute = _slots[i] + (h % 11 - 5) * 5;
      final depart = DateTime.utc(
        q.date.year,
        q.date.month,
        q.date.day,
      ).add(Duration(minutes: localMinute - from.utcOffsetMin));
      final duration = connects
          ? _minutes(from.distanceTo(world.airport(hub))) +
                _minutes(world.airport(hub).distanceTo(to)) +
                70 +
                h % 19 * 5
          : _minutes(km);
      final airline = world.airlines[h % world.airlines.length].code;
      final number = '${100 + (h ~/ 7) % 800}';
      final economy =
          (3500 + km * 8.2) *
          dayFactor /
          100 *
          (90 + (h ~/ 13) % 36) /
          100 *
          (connects ? .84 : 1);
      final price = (economy * q.cabin.percent / 100 / 100).round() * 100;
      flights.add(
        Flight(
          id: '$airline$number-$day',
          airline: airline,
          number: number,
          from: q.from,
          to: q.to,
          depart: depart,
          arrive: depart.add(Duration(minutes: duration)),
          priceCents: price,
          via: connects ? hub : null,
          seatsLeft: 1 + (h ~/ 3) % 9,
        ),
      );
    }
    return flights;
  }
}

// A network implementation. The JSON shapes match the models' fromJson.
//
// class RemoteFlightRepository implements FlightRepository {
//   RemoteFlightRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<List<Flight>> search(SearchQuery query) async {
//     final r = await _dio.get('/flights', queryParameters: query.toJson());
//     return [for (final j in r.data as List) Flight.fromJson(j)];
//   }
//   ...
// }

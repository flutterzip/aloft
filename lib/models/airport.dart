import 'dart:math' as math;

class Airport {
  const Airport({
    required this.code,
    required this.city,
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    required this.utcOffsetMin,
  });

  final String code;
  final String city;
  final String name;
  final String country;
  final double lat;
  final double lon;

  /// The airport's standard offset from UTC. Times on screen are local to
  /// the airport they belong to, as on a real ticket.
  final int utcOffsetMin;

  /// [utc] on this airport's clocks.
  DateTime local(DateTime utc) =>
      utc.toUtc().add(Duration(minutes: utcOffsetMin));

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        code.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        country.toLowerCase().contains(q);
  }

  /// Great-circle distance in kilometres.
  double distanceTo(Airport other) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLon = rad(other.lon - lon);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(a));
  }

  factory Airport.fromJson(Map<String, dynamic> j) => Airport(
    code: j['code'] as String,
    city: j['city'] as String,
    name: j['name'] as String,
    country: j['country'] as String,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    utcOffsetMin: j['utcOffsetMin'] as int,
  );
}

class Airline {
  const Airline({required this.code, required this.name});

  final String code;
  final String name;

  factory Airline.fromJson(Map<String, dynamic> j) =>
      Airline(code: j['code'] as String, name: j['name'] as String);
}

enum Cabin {
  economy('Economy', 100),
  premium('Premium Economy', 155),
  business('Business', 310),
  first('First', 520);

  const Cabin(this.label, this.percent);
  final String label;

  /// The fare as a percentage of the economy fare.
  final int percent;
}

/// The airports and airlines the app knows, by code.
class World {
  World({required List<Airport> airports, required List<Airline> airlines})
    : airports = List.unmodifiable(airports),
      airlines = List.unmodifiable(airlines),
      _airports = {for (final a in airports) a.code: a},
      _airlines = {for (final a in airlines) a.code: a};

  final List<Airport> airports;
  final List<Airline> airlines;
  final Map<String, Airport> _airports;
  final Map<String, Airline> _airlines;

  Airport airport(String code) => _airports[code]!;
  Airport? maybeAirport(String code) => _airports[code];
  Airline airline(String code) =>
      _airlines[code] ?? Airline(code: code, name: code);
}

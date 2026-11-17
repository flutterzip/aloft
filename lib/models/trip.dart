import 'airport.dart';
import 'flight.dart';

/// A booked flight. One leg is one trip, with its own boarding pass; the
/// two legs of a return share a booking reference.
class Trip {
  const Trip({
    required this.id,
    required this.pnr,
    required this.flight,
    required this.cabin,
    required this.seats,
    required this.travellers,
    required this.totalCents,
    required this.bookedAt,
    this.checkedIn = false,
    this.cancelled = false,
  });

  final String id;

  /// The six-character booking reference.
  final String pnr;
  final Flight flight;
  final Cabin cabin;

  /// One seat per traveller, in the same order.
  final List<String> seats;
  final List<String> travellers;
  final int totalCents;
  final DateTime bookedAt;
  final bool checkedIn;

  /// Cancelled by the person. The airline cancelling is on the flight.
  final bool cancelled;

  bool get isCancelled => cancelled || flight.cancelled;

  /// Past trips are the ones that have landed.
  bool isPast(DateTime now) => !now.isBefore(flight.actualArrive);

  /// Check-in opens a day before and closes when boarding starts.
  bool canCheckIn(DateTime now) {
    if (isCancelled || checkedIn) return false;
    final until = flight.actualDepart.difference(now);
    return until <= FlightStatus.checkInOpens &&
        until > FlightStatus.boardingOpens;
  }

  Trip copyWith({List<String>? seats, bool? checkedIn, bool? cancelled}) =>
      Trip(
        id: id,
        pnr: pnr,
        flight: flight,
        cabin: cabin,
        seats: seats ?? this.seats,
        travellers: travellers,
        totalCents: totalCents,
        bookedAt: bookedAt,
        checkedIn: checkedIn ?? this.checkedIn,
        cancelled: cancelled ?? this.cancelled,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pnr': pnr,
    'flight': flight.toJson(),
    'cabin': cabin.name,
    'seats': seats,
    'travellers': travellers,
    'totalCents': totalCents,
    'bookedAt': bookedAt.toUtc().toIso8601String(),
    'checkedIn': checkedIn,
    'cancelled': cancelled,
  };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'] as String,
    pnr: j['pnr'] as String,
    flight: Flight.fromJson(j['flight'] as Map<String, dynamic>),
    cabin: Cabin.values.asNameMap()[j['cabin']] ?? Cabin.economy,
    seats: (j['seats'] as List).cast<String>(),
    travellers: (j['travellers'] as List).cast<String>(),
    totalCents: j['totalCents'] as int,
    bookedAt: DateTime.parse(j['bookedAt'] as String),
    checkedIn: j['checkedIn'] as bool? ?? false,
    cancelled: j['cancelled'] as bool? ?? false,
  );

  /// A seed record, whose flight times are minutes from [base].
  factory Trip.fromSeed(Map<String, dynamic> j, DateTime base) {
    final flight = Flight.fromSeed({...j, 'id': j['id']}, base);
    return Trip(
      id: j['id'] as String,
      pnr: j['pnr'] as String,
      flight: flight,
      cabin: Cabin.values.asNameMap()[j['cabin']] ?? Cabin.economy,
      seats: (j['seats'] as List).cast<String>(),
      travellers: (j['travellers'] as List).cast<String>(),
      totalCents: j['totalCents'] as int,
      bookedAt: flight.depart.subtract(const Duration(days: 21)),
      checkedIn: j['checkedIn'] as bool? ?? false,
      cancelled: j['cancelledByYou'] as bool? ?? false,
    );
  }
}

/// The seats of a cabin, and which of them are gone. Fixed per flight, so
/// the map looks the same each time it is opened.
class SeatMap {
  SeatMap(this.flightId, this.cabin, {this.mine = const []});

  final String flightId;
  final Cabin cabin;

  /// Seats already held on this booking: never shown as taken.
  final List<String> mine;

  bool get wide => cabin == Cabin.business || cabin == Cabin.first;
  List<String> get letters =>
      wide ? const ['A', 'C', 'D', 'F'] : const ['A', 'B', 'C', 'D', 'E', 'F'];
  int get firstRow => switch (cabin) {
    Cabin.first => 1,
    Cabin.business => 4,
    Cabin.premium => 12,
    Cabin.economy => 18,
  };
  int get rowCount => switch (cabin) {
    Cabin.first => 3,
    Cabin.business => 7,
    Cabin.premium => 5,
    Cabin.economy => 16,
  };

  /// Rows with more room: the front row of the cabin and the exit row.
  bool extraLegroom(int row) => row == firstRow || row == firstRow + 6;

  bool taken(String seat) =>
      !mine.contains(seat) && _hash('$flightId$seat') % 100 < 36;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// The first [count] free seats, side by side where possible: what a
  /// booking gets before anyone picks.
  List<String> suggest(int count) {
    final picked = <String>[];
    for (var r = firstRow + 2; r < firstRow + rowCount; r++) {
      final free = [
        for (final l in letters)
          if (!taken('$r$l')) '$r$l',
      ];
      if (free.length >= count) return free.take(count).toList();
      picked.addAll(free);
      if (picked.length >= count) break;
    }
    return picked.take(count).toList();
  }
}

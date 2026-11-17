import 'airport.dart';
import 'when.dart';

/// One flight on one day: what a search returns, what a trip is booked on
/// and what the status page follows. Times are UTC; show them through the
/// airport they belong to.
class Flight {
  const Flight({
    required this.id,
    required this.airline,
    required this.number,
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.priceCents,
    this.via,
    this.seatsLeft = 9,
    this.delayMin = 0,
    this.cancelled = false,
  });

  final String id;

  /// Airline code, airport codes: resolved through [World].
  final String airline;
  final String number;
  final String from;
  final String to;
  final DateTime depart;
  final DateTime arrive;

  /// Per adult, in the cabin searched for.
  final int priceCents;

  /// The airport of the one stop, or null for a non-stop flight.
  final String? via;
  final int seatsLeft;

  /// How late it is running. Moves the departure and the arrival alike.
  final int delayMin;

  /// Cancelled by the airline.
  final bool cancelled;

  bool get nonStop => via == null;
  Duration get duration => arrive.difference(depart);
  DateTime get actualDepart => depart.add(Duration(minutes: delayMin));
  DateTime get actualArrive => arrive.add(Duration(minutes: delayMin));

  /// "AL 482".
  String get code => '$airline $number';

  /// Gate and terminal are fixed per flight, so every screen agrees.
  String get gate {
    final h = stableHash('gate$id');
    return '${'ABCDE'[h % 5]}${h ~/ 5 % 24 + 1}';
  }

  String get terminal => '${stableHash('terminal$id') % 3 + 1}';
  String get belt => '${stableHash('belt$id') % 9 + 1}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'airline': airline,
    'number': number,
    'from': from,
    'to': to,
    'depart': depart.toUtc().toIso8601String(),
    'arrive': arrive.toUtc().toIso8601String(),
    'priceCents': priceCents,
    'via': via,
    'seatsLeft': seatsLeft,
    'delayMin': delayMin,
    'cancelled': cancelled,
  };

  factory Flight.fromJson(Map<String, dynamic> j) => Flight(
    id: j['id'] as String,
    airline: j['airline'] as String,
    number: j['number'] as String,
    from: j['from'] as String,
    to: j['to'] as String,
    depart: DateTime.parse(j['depart'] as String),
    arrive: DateTime.parse(j['arrive'] as String),
    priceCents: j['priceCents'] as int,
    via: j['via'] as String?,
    seatsLeft: j['seatsLeft'] as int? ?? 9,
    delayMin: j['delayMin'] as int? ?? 0,
    cancelled: j['cancelled'] as bool? ?? false,
  );

  /// A seed record, whose times are minutes from [base].
  factory Flight.fromSeed(Map<String, dynamic> j, DateTime base) {
    final depart = base.toUtc().add(Duration(minutes: j['departInMin'] as int));
    return Flight(
      id: j['id'] as String? ?? '${j['airline']}${j['number']}',
      airline: j['airline'] as String,
      number: j['number'] as String,
      from: j['from'] as String,
      to: j['to'] as String,
      depart: depart,
      arrive: depart.add(Duration(minutes: j['durationMin'] as int)),
      priceCents: j['priceCents'] as int? ?? 0,
      via: j['via'] as String?,
      delayMin: j['delayMin'] as int? ?? 0,
      cancelled: j['cancelled'] as bool? ?? false,
    );
  }
}

/// Where a flight is in its day.
enum FlightPhase {
  scheduled('Scheduled'),
  checkIn('Check-in open'),
  boarding('Boarding'),
  inAir('In the air'),
  landed('Landed'),
  cancelled('Cancelled');

  const FlightPhase(this.label);
  final String label;
}

/// A flight's state at a moment, derived from its times and never stored,
/// so the trip card, the boarding pass and the status page cannot disagree.
class FlightStatus {
  const FlightStatus({
    required this.phase,
    required this.progress,
    required this.delayMin,
    required this.untilDepart,
    required this.untilArrive,
  });

  final FlightPhase phase;

  /// How far along the route the plane is, 0 to 1.
  final double progress;
  final int delayMin;
  final Duration untilDepart;
  final Duration untilArrive;

  bool get delayed => delayMin >= 15 && phase != FlightPhase.cancelled;
  bool get live => phase == FlightPhase.boarding || phase == FlightPhase.inAir;

  /// "Delayed 45m", or the phase.
  String get headline => phase == FlightPhase.cancelled
      ? phase.label
      : delayed && phase != FlightPhase.landed
      ? 'Delayed ${When.span(Duration(minutes: delayMin))}'
      : phase.label;

  /// "Departs in 10h 35m", "Lands in 2h 10m", "Landed 40m ago".
  String get line => switch (phase) {
    FlightPhase.cancelled => 'This flight will not operate',
    FlightPhase.landed => 'Landed ${When.span(untilArrive)} ago',
    FlightPhase.inAir => 'Lands in ${When.span(untilArrive)}',
    FlightPhase.boarding => 'Doors close in ${When.span(untilDepart)}',
    _ => 'Departs in ${When.span(untilDepart)}',
  };

  static const checkInOpens = Duration(hours: 24);
  static const boardingOpens = Duration(minutes: 45);

  factory FlightStatus.of(Flight f, DateTime now) {
    final depart = f.actualDepart;
    final arrive = f.actualArrive;
    final untilDepart = depart.difference(now);
    final untilArrive = arrive.difference(now);
    final FlightPhase phase;
    if (f.cancelled) {
      phase = FlightPhase.cancelled;
    } else if (!now.isBefore(arrive)) {
      phase = FlightPhase.landed;
    } else if (!now.isBefore(depart)) {
      phase = FlightPhase.inAir;
    } else if (untilDepart <= boardingOpens) {
      phase = FlightPhase.boarding;
    } else if (untilDepart <= checkInOpens) {
      phase = FlightPhase.checkIn;
    } else {
      phase = FlightPhase.scheduled;
    }
    final total = arrive.difference(depart).inSeconds;
    final done = now.difference(depart).inSeconds;
    return FlightStatus(
      phase: phase,
      progress: total <= 0 ? 0 : (done / total).clamp(0.0, 1.0),
      delayMin: f.delayMin,
      untilDepart: untilDepart,
      untilArrive: untilArrive.abs(),
    );
  }
}

/// What the person asked for on the home tab.
class SearchQuery {
  const SearchQuery({
    required this.from,
    required this.to,
    required this.date,
    this.returnDate,
    this.adults = 1,
    this.cabin = Cabin.economy,
  });

  final String from;
  final String to;

  /// A calendar day at the departure airport.
  final DateTime date;
  final DateTime? returnDate;
  final int adults;
  final Cabin cabin;

  bool get roundTrip => returnDate != null;

  /// The way back, as a one-way search.
  SearchQuery get back => SearchQuery(
    from: to,
    to: from,
    date: returnDate ?? date,
    adults: adults,
    cabin: cabin,
  );

  SearchQuery copyWith({
    String? from,
    String? to,
    DateTime? date,
    DateTime? returnDate,
    bool oneWay = false,
    int? adults,
    Cabin? cabin,
  }) => SearchQuery(
    from: from ?? this.from,
    to: to ?? this.to,
    date: date ?? this.date,
    returnDate: oneWay ? null : returnDate ?? this.returnDate,
    adults: adults ?? this.adults,
    cabin: cabin ?? this.cabin,
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'date': When.iso(date),
    'returnDate': returnDate == null ? null : When.iso(returnDate!),
    'adults': adults,
    'cabin': cabin.name,
  };

  factory SearchQuery.fromJson(Map<String, dynamic> j) => SearchQuery(
    from: j['from'] as String,
    to: j['to'] as String,
    date: DateTime.parse(j['date'] as String),
    returnDate: j['returnDate'] == null
        ? null
        : DateTime.parse(j['returnDate'] as String),
    adults: j['adults'] as int? ?? 1,
    cabin: Cabin.values.asNameMap()[j['cabin']] ?? Cabin.economy,
  );
}

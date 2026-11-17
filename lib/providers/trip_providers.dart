import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/motion.dart';
import '../models/account.dart';
import '../models/airport.dart';
import '../models/flight.dart';
import '../models/trip.dart';
import '../models/when.dart';
import '../services/store.dart';
import '../services/trip_repository.dart';
import 'core_providers.dart';

/// The time, refreshed every half minute so countdowns and the plane on a
/// route keep moving. Screens watch this, never the clock directly.
class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    // No timer when ambient motion is off (tests, automation).
    if (Motion.ambient) {
      final timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => state = clock(),
      );
      ref.onDispose(timer.cancel);
    }
    return clock();
  }

  void refresh() => state = ref.read(clockProvider)();
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

/// Every trip, soonest first.
class TripsNotifier extends AsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() async =>
      (await ref.watch(tripRepositoryProvider.future)).trips();

  Future<void> _reload() async {
    state = AsyncData(
      await (await ref.read(tripRepositoryProvider.future)).trips(),
    );
  }

  Future<List<Trip>> book({
    required List<Leg> legs,
    required Cabin cabin,
    required List<String> travellers,
    required PaymentCard card,
  }) async {
    final booked = await (await ref.read(
      tripRepositoryProvider.future,
    )).book(legs: legs, cabin: cabin, travellers: travellers, card: card);
    await _reload();
    return booked;
  }

  Future<void> save(Trip trip) async {
    await (await ref.read(tripRepositoryProvider.future)).save(trip);
    await _reload();
  }

  Future<void> checkIn(Trip trip) => save(trip.copyWith(checkedIn: true));
  Future<void> cancel(Trip trip) => save(trip.copyWith(cancelled: true));
  Future<void> restore(Trip trip) => save(trip.copyWith(cancelled: false));
  Future<void> changeSeats(Trip trip, List<String> seats) =>
      save(trip.copyWith(seats: seats));
}

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(
  TripsNotifier.new,
);

final tripProvider = Provider.family<Trip?, String>((ref, id) {
  for (final t in ref.watch(tripsProvider).valueOrNull ?? const <Trip>[]) {
    if (t.id == id) return t;
  }
  return null;
});

enum TripFilter { upcoming, past, cancelled }

/// Trips sorted into the three lists of the trips tab. Derived, so a trip
/// can never be in two of them or in none.
final tripsByFilterProvider = Provider<Map<TripFilter, List<Trip>>>((ref) {
  final now = ref.watch(nowProvider);
  final all = ref.watch(tripsProvider).valueOrNull ?? const <Trip>[];
  return {
    TripFilter.upcoming: [
      for (final t in all)
        if (!t.isCancelled && !t.isPast(now)) t,
    ],
    TripFilter.past: [
      for (final t in all.reversed)
        if (!t.isCancelled && t.isPast(now)) t,
    ],
    TripFilter.cancelled: [
      for (final t in all)
        if (t.isCancelled) t,
    ],
  };
});

/// The trip that leaves next, if there is one.
final nextTripProvider = Provider<Trip?>(
  (ref) => ref.watch(tripsByFilterProvider)[TripFilter.upcoming]!.firstOrNull,
);

/// What the profile shows: counted from flown trips, never stored.
typedef TravelStats = ({int flights, int km, int countries});

final travelStatsProvider = Provider<TravelStats>((ref) {
  final world = ref.watch(worldProvider).valueOrNull;
  final flown = ref.watch(tripsByFilterProvider)[TripFilter.past]!;
  if (world == null) return (flights: 0, km: 0, countries: 0);
  var km = 0.0;
  final countries = <String>{};
  for (final t in flown) {
    final from = world.airport(t.flight.from);
    final to = world.airport(t.flight.to);
    km += from.distanceTo(to);
    countries
      ..add(from.country)
      ..add(to.country);
  }
  return (flights: flown.length, km: km.round(), countries: countries.length);
});

/// Flights that can be followed: today's live ones and the person's own.
final liveFlightsProvider = FutureProvider<List<Flight>>((ref) async {
  final live = await (await ref.watch(flightRepositoryProvider.future)).live();
  final trips = await ref.watch(tripsProvider.future);
  final now = ref.read(clockProvider)();
  return [
    ...live,
    for (final t in trips)
      if (!t.cancelled &&
          t.flight.actualArrive.isAfter(
            now.subtract(const Duration(hours: 12)),
          ) &&
          t.flight.depart.isBefore(now.add(const Duration(days: 2))))
        t.flight,
  ];
});

/// "al482", "AL 482" and "AL482" are the same flight.
String normaliseFlightCode(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// The codes of the flights being followed on the status tab.
class TrackedNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final saved = ref.watch(storeProvider).strings(Store.tracked);
    if (saved != null) return saved;
    final seed = ref.watch(seedProvider).valueOrNull;
    return [
      for (final j in seed?.live ?? const <Map<String, dynamic>>[])
        if (j['tracked'] == true) '${j['airline']}${j['number']}',
    ];
  }

  Future<void> _set(List<String> codes) async {
    state = codes;
    await ref.read(storeProvider).setStrings(Store.tracked, codes);
  }

  bool has(String code) => state.contains(normaliseFlightCode(code));

  Future<void> add(String code, {int? at}) {
    final c = normaliseFlightCode(code);
    if (state.contains(c)) return Future.value();
    final next = [...state]..insert((at ?? 0).clamp(0, state.length), c);
    return _set(next);
  }

  Future<void> remove(String code) => _set([
    for (final c in state)
      if (c != normaliseFlightCode(code)) c,
  ]);
}

final trackedProvider = NotifierProvider<TrackedNotifier, List<String>>(
  TrackedNotifier.new,
);

/// The followed flights themselves, in the order they were followed.
final trackedFlightsProvider = Provider<List<Flight>>((ref) {
  final live = ref.watch(liveFlightsProvider).valueOrNull ?? const <Flight>[];
  final byCode = {for (final f in live) normaliseFlightCode(f.code): f};
  return [
    for (final c in ref.watch(trackedProvider))
      if (byCode[c] != null) byCode[c]!,
  ];
});

/// The search being put together on the home tab. Remembered between
/// launches; a date that has passed moves to today.
class SearchDraftNotifier extends Notifier<SearchQuery> {
  @override
  SearchQuery build() {
    final store = ref.watch(storeProvider);
    final today = When.dateOnly(ref.read(clockProvider)());
    final saved = store.json<Map<String, dynamic>>(Store.lastSearch);
    if (saved != null) {
      final q = SearchQuery.fromJson(saved);
      final date = q.date.isBefore(today) ? today : q.date;
      final back = q.returnDate;
      return SearchQuery(
        from: q.from,
        to: q.to,
        date: date,
        returnDate: back == null ? null : (back.isBefore(date) ? date : back),
        adults: q.adults,
        cabin: q.cabin,
      );
    }
    final home = ref.watch(seedProvider).valueOrNull?.homeAirport ?? 'LOS';
    return SearchQuery(
      from: home,
      to: home == 'LHR' ? 'JFK' : 'LHR',
      date: today.add(const Duration(days: 7)),
    );
  }

  void set(SearchQuery q) {
    state = q;
    ref.read(storeProvider).setJson(Store.lastSearch, q.toJson());
  }

  void swap() => set(state.copyWith(from: state.to, to: state.from));
}

final searchDraftProvider = NotifierProvider<SearchDraftNotifier, SearchQuery>(
  SearchDraftNotifier.new,
);

/// The last few searches run, newest first.
class RecentSearchesNotifier extends Notifier<List<SearchQuery>> {
  static const keep = 4;

  @override
  List<SearchQuery> build() => [
    for (final s
        in ref.watch(storeProvider).strings(Store.recentSearches) ??
            const <String>[])
      SearchQuery.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> _set(List<SearchQuery> list) async {
    state = list;
    await ref.read(storeProvider).setStrings(Store.recentSearches, [
      for (final q in list) jsonEncode(q.toJson()),
    ]);
  }

  Future<void> add(SearchQuery q) => _set(
    [
      q,
      for (final r in state)
        if (r.from != q.from || r.to != q.to) r,
    ].take(keep).toList(),
  );

  Future<void> remove(SearchQuery q) => _set([
    for (final r in state)
      if (!identical(r, q)) r,
  ]);

  Future<void> clear() => _set(const []);
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<SearchQuery>>(
      RecentSearchesNotifier.new,
    );

/// Search results, cached by the query's JSON so a rebuild never searches
/// again.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<Flight>, String>((ref, key) async {
      final query = SearchQuery.fromJson(
        jsonDecode(key) as Map<String, dynamic>,
      );
      return (await ref.watch(flightRepositoryProvider.future)).search(query);
    });

/// The lowest fare on each day around a search, for the date strip.
final faresProvider = FutureProvider.autoDispose
    .family<Map<DateTime, int>, String>((ref, key) async {
      final query = SearchQuery.fromJson(
        jsonDecode(key) as Map<String, dynamic>,
      );
      final today = When.dateOnly(ref.read(clockProvider)());
      final first = query.date.subtract(const Duration(days: 3));
      final start = first.isBefore(today) ? today : first;
      return (await ref.watch(flightRepositoryProvider.future)).fares(query, [
        for (var i = 0; i < 9; i++) start.add(Duration(days: i)),
      ]);
    });

String searchKey(SearchQuery q) => jsonEncode(q.toJson());

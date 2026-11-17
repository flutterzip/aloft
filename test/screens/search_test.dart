import 'package:aloft/models/airport.dart';
import 'package:aloft/models/flight.dart';
import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/screens/home/home_tab.dart';
import 'package:aloft/screens/home/search_card.dart';
import 'package:aloft/screens/search/flight_card.dart';
import 'package:aloft/screens/search/results_screen.dart';
import 'package:aloft/services/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUpAll(quietMotion);
  final day = DateTime(2026, 11, 17);

  group('home', () {
    testWidgets('greets the person by name and shows the form and routes', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      expect(find.text('Welcome, Olympicson'), findsOneWidget);
      expect(find.text('Where to next?'), findsOneWidget);
      expect(find.text('Popular routes'), findsOneWidget);
      // The trip that leaves next is in the header.
      expect(find.byKey(const Key('home-next-trip')), findsOneWidget);
      expect(find.textContaining('LHR in 10h 35m'), findsOneWidget);
      // The first search starts from the seeded home airport.
      expect(c.read(searchDraftProvider).from, seed.homeAirport);
    });

    testWidgets('swap turns the route round and is remembered', (t) async {
      phone(t);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      await t.tap(find.byKey(SearchKeys.swap));
      await t.pumpAndSettle();
      final q = c.read(searchDraftProvider);
      expect((q.from, q.to), ('LHR', 'LOS'));
      expect(
        store.json<Map<String, dynamic>>(Store.lastSearch)!['from'],
        'LHR',
      );
    });

    testWidgets('the airport sheet searches, and will not offer the far end', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      await t.tap(find.byKey(SearchKeys.to));
      await t.pumpAndSettle();
      expect(find.text('Flying to'), findsOneWidget);
      // Lagos is where the trip starts: shown, explained, not tappable.
      expect(find.text('The other end of this trip'), findsOneWidget);
      await t.enterText(find.byKey(const Key('airport-search')), 'zzz');
      await t.pumpAndSettle();
      expect(find.text('No airport matches'), findsOneWidget);
      await t.enterText(find.byKey(const Key('airport-search')), 'nair');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('airport-NBO')));
      await t.pumpAndSettle();
      expect(c.read(searchDraftProvider).to, 'NBO');
      expect(find.text('Nairobi'), findsWidgets);
    });

    testWidgets('a return needs both days before the sheet will close', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      await t.tap(find.byKey(SearchKeys.back));
      await t.pumpAndSettle();
      expect(find.text('When are you travelling?'), findsOneWidget);
      await t.tap(find.byKey(const Key('day-2026-11-20')));
      await t.pumpAndSettle();
      expect(find.text('Now pick the day you come back'), findsOneWidget);
      await t.tap(find.byKey(const Key('date-done')));
      await t.pumpAndSettle();
      // Still open: the button said what was missing instead of closing.
      expect(find.text('When are you travelling?'), findsOneWidget);
      await t.tap(find.byKey(const Key('day-2026-11-26')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('date-done')));
      await t.pumpAndSettle();
      final q = c.read(searchDraftProvider);
      expect(q.date, DateTime(2026, 11, 20));
      expect(q.returnDate, DateTime(2026, 11, 26));
      // And One way drops the return again.
      await t.tap(find.byKey(const ValueKey('segment-One way')));
      await t.pumpAndSettle();
      expect(c.read(searchDraftProvider).roundTrip, isFalse);
    });

    testWidgets('travellers stop at four and the cabin is chosen', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const HomeTab());
      await t.tap(find.byKey(SearchKeys.party));
      await t.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await t.tap(find.byKey(const Key('party-more')));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.text('Up to 4 on one booking'), findsOneWidget);
      await t.tap(find.byKey(const Key('cabin-business')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('party-done')));
      await t.pumpAndSettle();
      final q = c.read(searchDraftProvider);
      expect((q.adults, q.cabin), (4, Cabin.business));
      expect(find.text('4 travellers, Business'), findsOneWidget);
    });

    testWidgets('recent searches can be removed and cleared', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      final recents = c.read(recentSearchesProvider.notifier);
      await recents.add(SearchQuery(from: 'LOS', to: 'LHR', date: day));
      await recents.add(SearchQuery(from: 'ACC', to: 'JFK', date: day));
      await pumpScreen(t, c, const HomeTab());
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byKey(const Key('recent-ACC-JFK')), findsOneWidget);
      await tapVisible(t, find.text('Clear'));
      expect(find.text('Recent searches'), findsNothing);
      expect(c.read(recentSearchesProvider), isEmpty);
    });
  });

  group('results', () {
    testWidgets('lists the flights cheapest first, and sorts', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      final q = SearchQuery(from: 'LOS', to: 'LHR', date: day);
      await pumpScreen(t, c, ResultsScreen(query: q));
      expect(find.text('Choose your flight'), findsOneWidget);
      final cards = t.widgetList<FlightCard>(find.byType(FlightCard)).toList();
      expect(cards, isNotEmpty);
      expect(cards.first.best, isTrue);
      expect(find.text('Best fare'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('segment-Fastest')));
      await t.pumpAndSettle();
      final fastest = t.widgetList<FlightCard>(find.byType(FlightCard)).first;
      final all = await c.read(searchResultsProvider(searchKey(q)).future);
      expect(
        fastest.flight.duration,
        all.map((f) => f.duration).reduce((a, b) => a < b ? a : b),
      );
    });

    testWidgets('non-stop on a route too far names it and offers a way on', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(
        t,
        c,
        ResultsScreen(
          query: SearchQuery(from: 'LOS', to: 'SYD', date: day),
        ),
      );
      expect(find.byType(FlightCard), findsWidgets);
      await t.tap(find.byKey(const Key('filter-nonstop')));
      await t.pumpAndSettle();
      expect(find.text('No non-stop flights on this route'), findsOneWidget);
      expect(find.byType(FlightCard), findsNothing);
      await t.tap(find.text('Show flights with a stop'));
      await t.pumpAndSettle();
      expect(find.byType(FlightCard), findsWidgets);
    });

    testWidgets(
      'late in the day there is nothing left, and tomorrow is one tap',
      (t) async {
        phone(t);
        final (c, _) = await makeContainer(
          seed,
          signedIn: seed.profile,
          now: DateTime.utc(2026, 11, 17, 23, 30),
        );
        await pumpScreen(
          t,
          c,
          ResultsScreen(
            query: SearchQuery(from: 'LOS', to: 'LHR', date: day),
          ),
        );
        expect(find.text('No flights left on Tue, 17 Nov'), findsOneWidget);
        await t.tap(find.text('Try the next day'));
        await t.pumpAndSettle();
        expect(find.byType(FlightCard), findsWidgets);
      },
    );

    testWidgets('another day on the fare strip searches again', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(
        t,
        c,
        ResultsScreen(
          query: SearchQuery(from: 'LOS', to: 'LHR', date: day),
        ),
      );
      final before = t
          .widgetList<FlightCard>(find.byType(FlightCard))
          .first
          .flight
          .id;
      await t.tap(find.byKey(const Key('fare-2026-11-18')));
      await t.pumpAndSettle();
      final after = t
          .widgetList<FlightCard>(find.byType(FlightCard))
          .first
          .flight
          .id;
      expect(after, isNot(before));
      expect(after, endsWith('2026-11-18'));
    });

    testWidgets('a return asks for the way back after the way out', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(
        t,
        c,
        ResultsScreen(
          query: SearchQuery(
            from: 'LOS',
            to: 'LHR',
            date: day,
            returnDate: DateTime(2026, 11, 24),
          ),
        ),
      );
      expect(find.text('Choose your flight out'), findsOneWidget);
      await t.tap(find.byType(FlightCard).first);
      await t.pumpAndSettle();
      expect(find.text('Choose your flight back'), findsOneWidget);
      final back = t
          .widgetList<FlightCard>(find.byType(FlightCard))
          .last
          .flight;
      expect((back.from, back.to), ('LHR', 'LOS'));
    });
  });
}

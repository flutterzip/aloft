import 'package:aloft/providers/account_providers.dart';
import 'package:aloft/providers/session_providers.dart';
import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/screens/profile/cards_screen.dart';
import 'package:aloft/screens/profile/profile_tab.dart';
import 'package:aloft/screens/profile/traveller_sheet.dart';
import 'package:aloft/screens/profile/travellers_screen.dart';
import 'package:aloft/services/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  setUpAll(quietMotion);

  testWidgets('shows the person and what they have flown', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    expect(find.text('Olympicson'), findsOneWidget);
    expect(find.text('hello@flutterzip.com'), findsOneWidget);
    // Counted from the three seeded past trips, never stored.
    final stats = c.read(travelStatsProvider);
    expect(stats.flights, 3);
    expect(stats.countries, 4);
    expect(stats.km, inInclusiveRange(7000, 7500));
    expect(find.text('3'), findsWidgets);
    expect(find.text('Flights'), findsOneWidget);
  });

  testWidgets('appearance is chosen and remembered', (t) async {
    phone(t);
    final (c, store) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    await tapVisible(t, find.byKey(const Key('appearance-dark')));
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(store.string(Store.themeMode), 'dark');
  });

  testWidgets('renders in dark', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab(), mode: ThemeMode.dark);
    expect(find.text('Olympicson'), findsOneWidget);
  });

  group('travellers', () {
    testWidgets('lists the seeded people', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TravellersScreen());
      expect(find.text('Olympicson'), findsOneWidget);
      expect(find.text('Ada Okafor'), findsOneWidget);
      expect(find.textContaining('Passport ending 4471'), findsOneWidget);
      expect(find.textContaining('No passport saved'), findsOneWidget);
    });

    testWidgets('add checks the form, then saves', (t) async {
      phone(t);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TravellersScreen());
      await t.tap(find.byKey(const Key('traveller-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(TravellerKeys.name), 'Zainab Bello');
      await t.enterText(find.byKey(TravellerKeys.born), '1700');
      await t.enterText(find.byKey(TravellerKeys.passport), 'ab');
      await t.tap(find.byKey(TravellerKeys.save));
      await t.pumpAndSettle();
      expect(find.text('That year does not look right.'), findsOneWidget);
      expect(find.text('Enter a nationality.'), findsOneWidget);
      expect(
        find.text('Enter the last 4 characters, or leave it empty.'),
        findsOneWidget,
      );
      await t.enterText(find.byKey(TravellerKeys.born), '1990');
      await t.enterText(find.byKey(TravellerKeys.passport), 'ab12');
      await t.enterText(find.byKey(TravellerKeys.nationality), 'Nigeria');
      await t.tap(find.byKey(TravellerKeys.save));
      await t.pumpAndSettle();
      final saved = c.read(travellersProvider).value!.last;
      expect(
        (saved.name, saved.born, saved.passport),
        ('Zainab Bello', 1990, 'AB12'),
      );
      expect(store.json<List<dynamic>>(Store.travellers), hasLength(4));
      expect(find.text('Zainab Bello'), findsOneWidget);
    });

    testWidgets('edit changes a traveller in place', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TravellersScreen());
      await t.tap(find.text('Edit').at(1));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(TravellerKeys.name), 'Ada Bello');
      await t.tap(find.byKey(TravellerKeys.save));
      await t.pumpAndSettle();
      final list = c.read(travellersProvider).value!;
      expect(list, hasLength(3));
      expect(list[1].name, 'Ada Bello');
    });

    testWidgets(
      'remove asks first, and removing everyone shows the empty state',
      (t) async {
        phone(t);
        final (c, _) = await makeContainer(seed, signedIn: seed.profile);
        await pumpScreen(t, c, const TravellersScreen());
        await t.tap(find.text('Remove').first);
        await t.pumpAndSettle();
        expect(find.text('Remove Olympicson?'), findsOneWidget);
        await t.tap(find.text('Keep it'));
        await t.pumpAndSettle();
        expect(c.read(travellersProvider).value, hasLength(3));
        for (var i = 0; i < 3; i++) {
          await t.tap(find.text('Remove').first);
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('confirm-remove')));
          await t.pumpAndSettle();
        }
        expect(c.read(travellersProvider).value, isEmpty);
        expect(find.text('No travellers yet'), findsOneWidget);
      },
    );
  });

  testWidgets('cards: the seeded two, a default, and remove', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const CardsScreen());
    expect(find.textContaining('4242'), findsOneWidget);
    expect(find.textContaining('0002'), findsOneWidget);
    await t.tap(find.text('Make default'));
    await t.pumpAndSettle();
    expect(c.read(defaultCardProvider)!.last4, '0002');
    await t.tap(find.text('Remove').first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-remove')));
    await t.pumpAndSettle();
    expect(c.read(cardsProvider).value, hasLength(1));
  });
}

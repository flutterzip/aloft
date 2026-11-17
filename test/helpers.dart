import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloft/config/app_theme.dart';
import 'package:aloft/config/app_timing.dart';
import 'package:aloft/config/motion.dart';
import 'package:aloft/models/account.dart';
import 'package:aloft/providers/account_providers.dart';
import 'package:aloft/providers/core_providers.dart';
import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/providers/session_providers.dart';
import 'package:aloft/services/seed.dart';
import 'package:aloft/services/store.dart';

/// The real seed, read from disk with dart:io. Call outside testWidgets: an
/// asset-bundle load inside the fake-async zone hangs every test after the
/// first in a file.
Seed readSeed() => Seed.fromSources({
  for (final f in Seed.files) f: File('assets/data/$f.json').readAsStringSync(),
});

/// No ambient loops (so pumpAndSettle settles) and no deliberate waits.
void quietMotion() {
  Motion.ambient = false;
  AppTiming.scale = 0;
}

/// An iPhone-sized surface. The 800x600 default hides phone layout bugs.
void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The fixed "now" every test runs at, unless it picks another. It is
/// also the moment the seed's relative times are counted from, so the
/// seeded trips and live flights are exactly as far away as their files say.
final testNow = DateTime.utc(2026, 11, 10, 12, 0);

Future<(ProviderContainer, Store)> makeContainer(
  Seed seed, {
  Map<String, Object> prefs = const {},
  UserProfile? signedIn,
  DateTime? now,
  List<Override> overrides = const [],
}) async {
  final clock = now ?? testNow;
  SharedPreferences.setMockInitialValues({
    for (final e in prefs.entries) 'flutter.${e.key}': e.value,
  });
  final store = Store(await SharedPreferences.getInstance());
  if (signedIn != null) {
    await store.setJson(Store.session, {'email': signedIn.email});
  }
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => clock),
      // Counted from testNow whatever the clock says, so a test can stand
      // later in the day and find the seeded flights further along.
      seedStampProvider.overrideWithValue(testNow),
      ...overrides,
      seedProvider.overrideWith((_) async => seed),
    ],
  );
  addTearDown(container.dispose);
  return (container, store);
}

/// Loads everything a screen may watch, so nothing first resolves during a
/// build.
Future<void> warm(ProviderContainer container) async {
  await container.read(seedProvider.future);
  await container.read(worldProvider.future);
  await container.read(popularRoutesProvider.future);
  await container.read(authRepositoryProvider.future);
  await container.read(tripsProvider.future);
  await container.read(liveFlightsProvider.future);
  await container.read(travellersProvider.future);
  await container.read(cardsProvider.future);
  await container.read(profileProvider.future);
}

/// Pumps [child] in a themed MaterialApp inside [container], with the
/// data already loaded. Reduce motion is on, so shader and particle
/// effects take their plain paths and everything settles.
Future<void> pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await warm(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        // Tab pages live inside the shell's Scaffold in the app; give them
        // one here so toasts have somewhere to show.
        home: Scaffold(resizeToAvoidBottomInset: false, body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Taps something that may be off screen in a list.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

import 'dart:io';

import 'package:aloft/app.dart';
import 'package:aloft/config/app_brand.dart';
import 'package:aloft/config/app_timing.dart';
import 'package:aloft/config/launch_hooks.dart';
import 'package:aloft/providers/session_providers.dart';
import 'package:aloft/providers/trip_providers.dart';
import 'package:aloft/screens/auth/auth_screen.dart';
import 'package:aloft/screens/booking/booking_screen.dart';
import 'package:aloft/screens/booking/confirmed_screen.dart';
import 'package:aloft/screens/home/home_tab.dart';
import 'package:aloft/screens/home/search_card.dart';
import 'package:aloft/screens/profile/profile_tab.dart';
import 'package:aloft/screens/search/flight_card.dart';
import 'package:aloft/screens/search/results_screen.dart';
import 'package:aloft/screens/shell/main_shell.dart';
import 'package:aloft/screens/splash/splash_overlay.dart';
import 'package:aloft/screens/status/status_tab.dart';
import 'package:aloft/screens/trips/boarding_pass.dart';
import 'package:aloft/screens/trips/trip_detail_screen.dart';
import 'package:aloft/screens/trips/trips_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aloft/kit/kit.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester t, ProviderContainer c) async {
  await warm(c);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: AloftApp(),
      ),
    ),
  );
}

/// Steps past the splash in frames: one long pump would run its timeline,
/// its awaits and the first screen's entrance only once.
Future<void> pumpPastSplash(WidgetTester t) async {
  final frames = AppTiming.splashTotal.inMilliseconds ~/ 50 + 12;
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder tab(String label) => find.descendant(
  of: find.byType(LiquidGlassTabBar),
  matching: find.text(label),
);

void main() {
  final seed = readSeed();
  setUp(quietMotion);
  tearDown(() => AppTiming.scale = 0);

  group('first screen', () {
    testWidgets('a first launch opens on sign in', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('a remembered session opens on search', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(HomeTab), findsOneWidget);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });
  });

  group('splash', () {
    testWidgets('plays over a blank page, then hands over without a remount', (
      t,
    ) async {
      phone(t);
      AppTiming.scale = 1;
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashOverlay), findsOneWidget);
      expect(find.byType(HomeTab), findsNothing);
      // The tagline sits on its own Material: no debug underline.
      final style = DefaultTextStyle.of(
        t.element(find.text(AppBrand.tagline)),
      ).style;
      expect(style.decoration, isNot(TextDecoration.underline));

      // Step until the first screen is mounted under the leaving splash.
      for (
        var i = 0;
        i < 120 && c.read(splashPhaseProvider) != SplashPhase.leaving;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(c.read(splashPhaseProvider), SplashPhase.leaving);
      final during = t.state(find.byType(MainShell));
      await pumpPastSplash(t);
      expect(c.read(splashPhaseProvider), SplashPhase.done);
      expect(find.byType(SplashOverlay), findsNothing);
      // The same State before and after: the first screen was not rebuilt
      // from scratch, so its entrance cannot have played twice.
      expect(identical(t.state(find.byType(MainShell)), during), isTrue);
    });
  });

  group('shell', () {
    testWidgets('tabs switch and keep their place; results open in the tab', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      await t.tap(tab('Trips'));
      await t.pumpAndSettle();
      expect(c.read(shellTabProvider), ShellTab.trips);
      expect(find.byType(TripsTab), findsOneWidget);
      await t.tap(tab('Status'));
      await t.pumpAndSettle();
      expect(find.byType(StatusTab), findsOneWidget);
      await t.tap(tab('You'));
      await t.pumpAndSettle();
      expect(find.byType(ProfileTab), findsOneWidget);

      await t.tap(tab('Search'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(HomeTab),
          matching: find.byKey(SearchKeys.submit),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
      // Results are inside the tab: the glass bar stays.
      expect(find.byType(LiquidGlassTabBar).hitTestable(), findsOneWidget);
      await t.tap(tab('You'));
      await t.pumpAndSettle();
      await t.tap(tab('Search'));
      await t.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
      // Tapping the tab you are on goes back to its first page.
      await t.tap(tab('Search'));
      await t.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsNothing);
    });

    testWidgets('the glass bar\'s own pane opens the next boarding pass', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(LiquidGlassTabBar),
          matching: find.byIcon(Icons.qr_code_2_rounded),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Your boarding pass'), findsOneWidget);
      expect(find.byType(BoardingPass), findsOneWidget);
      expect(find.byKey(const Key('pass-check-in')), findsOneWidget);
    });
  });

  testWidgets('the whole journey: sign in, search, book, see the trip', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed);
    await pumpApp(t, c);
    await t.pumpAndSettle();

    await t.enterText(find.byKey(AuthKeys.email), 'me@example.com');
    await t.enterText(find.byKey(AuthKeys.password), 'secret1');
    await tapVisible(t, find.byKey(AuthKeys.submit));
    expect(find.byType(HomeTab), findsOneWidget);
    expect(c.read(sessionProvider), 'me@example.com');

    await t.tap(find.byKey(SearchKeys.submit));
    await t.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    await t.tap(find.byType(FlightCard).first);
    await t.pumpAndSettle();
    expect(find.byType(BookingScreen), findsOneWidget);
    // Booking is its own mode: it covers the tab bar.
    expect(find.byType(LiquidGlassTabBar).hitTestable(), findsNothing);

    await t.tap(find.byType(PayButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    await t.pumpAndSettle();
    expect(find.byType(ConfirmedScreen), findsOneWidget);

    await t.tap(find.byKey(const Key('confirmed-view-trip')));
    await t.pumpAndSettle();
    expect(c.read(shellTabProvider), ShellTab.trips);
    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(c.read(tripsProvider).value!.length, seed.trips.length + 1);
    // Search was left on its first page behind the booking.
    await t.tap(tab('Search'));
    await t.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsNothing);
  });

  testWidgets('sign out goes back to sign in', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpApp(t, c);
    await t.pumpAndSettle();
    await t.tap(tab('You'));
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(ProfileKeys.signOut));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(c.read(sessionProvider), isNull);
  });

  group('house rules', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('no em dashes in anything a person can read', () {
      for (final f in sources) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          expect(line.contains('—'), isFalse, reason: '${f.path}:${i + 1}');
        }
      }
    });

    test('launch hooks are off unless asked for', () {
      expect(LaunchHooks.start, isEmpty);
      expect(
        File('lib/config/launch_hooks.dart').readAsStringSync(),
        contains("defaultValue: ''"),
      );
    });

    test('colours are defined in the palette and nowhere else', () {
      final allowed = {
        'lib/config/palette.dart',
        // Apple's and Google's marks are fixed by their guidelines.
        'lib/widgets/social_buttons.dart',
      };
      final literal = RegExp(r'Color\(0x|Color\.from|Colors\.(?!transparent)');
      for (final f in sources) {
        if (allowed.contains(f.path)) continue;
        // The copied-in components: they take the app's colours as arguments
        // and only keep neutral defaults of their own.
        if (f.path.startsWith('lib/kit/')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          expect(
            literal.hasMatch(lines[i]),
            isFalse,
            reason: '${f.path}:${i + 1} ${lines[i].trim()}',
          );
        }
      }
    });

    test('no source file is longer than 500 lines', () {
      for (final f in sources) {
        expect(
          f.readAsLinesSync().length,
          lessThanOrEqualTo(500),
          reason: f.path,
        );
      }
    });
  });
}

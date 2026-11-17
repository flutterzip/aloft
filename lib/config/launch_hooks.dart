import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/flight.dart';
import '../models/when.dart';
import '../screens/actions.dart';
import '../screens/profile/cards_screen.dart';
import '../screens/profile/travellers_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/trips/trip_detail_screen.dart';
import '../services/store.dart';

/// Opens the app in a given state, for screenshots and recordings. Off
/// unless asked for, so a normal build is unaffected:
///
///   flutter run --dart-define=start=signedIn,tab=trips
///
/// Tokens, comma separated:
///   fresh           forget everything first, as on a first launch
///   signedIn        sign in as the demo person
///   dark | light    force the appearance
///   tab=NAME        home, trips, status or profile
///   open=WHAT       results (the default search), trip:ID, pass,
///                   travellers or cards
///   touch=SCRIPT    taps and waits played after the page opens, for
///                   recording motion hands-free: `600/220x640/900/200x300`
///                   waits 600 ms, taps at (220, 640), waits 900 ms, taps
///                   again. `AxB>CxD` drags from one point to the other.
abstract final class LaunchHooks {
  /// What was asked for at build time. Empty in anything that ships.
  static const start = String.fromEnvironment('start', defaultValue: '');

  /// A one-shot request left as a file in the app's Documents folder by
  /// a script, so a debug build can be relaunched into a state
  /// without rebuilding. Never read in a release build.
  static const requestFile = 'launch_start.txt';
  static String _asked = start;

  static List<String> get _tokens => [
    for (final t in _asked.split(','))
      if (t.trim().isNotEmpty) t.trim(),
  ];

  static String? _value(String key) {
    for (final t in _tokens) {
      if (t.startsWith('$key=')) return t.substring(key.length + 1);
    }
    return null;
  }

  /// Before the first frame: stored state the first screen reads.
  static Future<void> prepare(Store store) async {
    if (start.isEmpty && !kReleaseMode) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$requestFile');
        if (file.existsSync()) {
          _asked = file.readAsStringSync().trim();
          file.deleteSync();
        }
      } catch (_) {
        // No request, or nowhere to look: start normally.
      }
    }
    final tokens = _tokens;
    if (tokens.isEmpty) return;
    if (tokens.contains('fresh')) await store.reset();
    if (tokens.contains('signedIn')) {
      await store.setJson(Store.session, {'email': 'hello@flutterzip.com'});
    }
    if (tokens.contains('dark')) await store.setString(Store.themeMode, 'dark');
    if (tokens.contains('light')) {
      await store.setString(Store.themeMode, 'light');
    }
  }

  /// After the splash has gone: the tab and page to land on. Pages open
  /// through the same functions the UI uses.
  static void run(BuildContext context, ProviderContainer container) {
    if (_tokens.isEmpty) return;
    final tab = ShellTab.values.asNameMap()[_value('tab')];
    if (tab != null) container.read(shellTabProvider.notifier).state = tab;
    final touch = _value('touch');
    if (touch != null) _play(touch);
    final open = _value('open');
    if (open == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final nav = tabNavigator(context);
      final [what, ...rest] = open.split(':');
      final id = rest.join(':');
      switch (what) {
        case 'results':
          final day = When.dateOnly(
            DateTime.now(),
          ).add(const Duration(days: 7));
          runSearch(context, SearchQuery(from: 'LOS', to: 'LHR', date: day));
        case 'trip':
          nav.push(tabRoute(TripDetailScreen(tripId: id)));
        case 'pass':
          openNextPass(context);
        case 'travellers':
          nav.push(tabRoute(const TravellersScreen()));
        case 'cards':
          nav.push(tabRoute(const CardsScreen()));
      }
    });
  }

  /// Plays a touch script through the gesture binding, so real recognisers
  /// fire exactly as for a finger.
  static Future<void> _play(String script) async {
    Offset? point(String s) {
      final xy = s.split('x').map(double.tryParse).toList();
      return xy.length == 2 && xy[0] != null && xy[1] != null
          ? Offset(xy[0]!, xy[1]!)
          : null;
    }

    var pointer = 900;
    Duration stamp() =>
        Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    void send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);
    for (final step in script.split('/')) {
      if (step.contains('>')) {
        final [a, b] = step.split('>').map(point).toList();
        if (a == null || b == null) continue;
        final id = pointer++;
        send(PointerDownEvent(pointer: id, position: a, timeStamp: stamp()));
        const frames = 18;
        for (var i = 1; i <= frames; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          send(
            PointerMoveEvent(
              pointer: id,
              position: Offset.lerp(a, b, i / frames)!,
              delta: (b - a) / frames.toDouble(),
              timeStamp: stamp(),
            ),
          );
        }
        send(PointerUpEvent(pointer: id, position: b, timeStamp: stamp()));
      } else if (step.contains('x')) {
        final at = point(step);
        if (at == null) continue;
        final id = pointer++;
        send(PointerDownEvent(pointer: id, position: at, timeStamp: stamp()));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        send(PointerUpEvent(pointer: id, position: at, timeStamp: stamp()));
      } else {
        await Future<void>.delayed(
          Duration(milliseconds: int.tryParse(step) ?? 0),
        );
      }
    }
  }
}

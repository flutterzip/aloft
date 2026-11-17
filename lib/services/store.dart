import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User state on top of the seed: the session, travellers, cards, booked
/// trips, followed flights and recent searches.
///
/// A thin wrapper so every key is named in one place. Reads are synchronous
/// (the instance is loaded before `runApp`), so screens never flash empty
/// state on launch. Not secure storage: no secrets go here, and a card is
/// only ever its brand, last four digits, expiry and holder.
class Store {
  Store(this._prefs);

  final SharedPreferences _prefs;

  /// Who is signed in: just their email. Never the profile itself.
  static const session = 'session';
  static const profile = 'profile';
  static const travellers = 'travellers';
  static const cards = 'cards';
  static const defaultCard = 'default_card';

  /// Trips booked on this device, and what changed on the seeded ones
  /// (a seat, a check-in, a cancellation), by trip id.
  static const placedTrips = 'placed_trips';
  static const tripChanges = 'trip_changes';

  /// Flight codes being followed on the status tab.
  static const tracked = 'tracked';
  static const lastSearch = 'last_search';
  static const recentSearches = 'recent_searches';
  static const themeMode = 'theme_mode';

  static const all = [
    session,
    profile,
    travellers,
    cards,
    defaultCard,
    placedTrips,
    tripChanges,
    tracked,
    lastSearch,
    recentSearches,
    themeMode,
  ];

  String? string(String key) => _prefs.getString(key);

  Future<void> setString(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);

  T? json<T>(String key) {
    final s = _prefs.getString(key);
    return s == null ? null : jsonDecode(s) as T;
  }

  Future<void> setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  List<String>? strings(String key) => _prefs.getStringList(key);

  Future<void> setStrings(String key, Iterable<String> v) =>
      _prefs.setStringList(key, v.toList());

  /// Back to a first launch: the seed shows through again.
  Future<void> reset() async {
    for (final k in all) {
      await _prefs.remove(k);
    }
  }
}

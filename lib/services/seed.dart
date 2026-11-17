import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/app_brand.dart';
import '../models/account.dart';
import '../models/airport.dart';

/// Everything bundled under assets/data/, parsed once.
///
/// Seed is read-only and edited by whoever uses the template; one JSON file
/// per entity, in the shape an API would send. What the user changes is
/// state, kept in [Store], never written back here. Only the Local and Demo
/// repositories read it.
class Seed {
  const Seed({
    required this.world,
    required this.hubs,
    required this.popular,
    required this.trips,
    required this.live,
    required this.travellers,
    required this.cards,
    required this.profile,
    required this.demoEmail,
    required this.wrongPassword,
    required this.decliningCardLast4,
    required this.homeAirport,
  });

  final World world;

  /// Where a journey too long to fly in one go changes planes.
  final List<String> hubs;

  /// Route pairs shown on the home tab: `(from, to)`.
  final List<(String, String)> popular;

  /// Kept raw: their relative times become dates in the repositories.
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> live;
  final List<Traveller> travellers;
  final List<PaymentCard> cards;
  final UserProfile profile;
  final String demoEmail;

  /// Typing this password shows the wrong-password state; any other
  /// well-formed sign-in succeeds, so a demo never dead-ends.
  final String wrongPassword;

  /// Paying with a card ending in these digits is declined, so the failure
  /// path can be seen.
  final String decliningCardLast4;

  /// Where a first search starts from.
  final String homeAirport;

  static const files = [
    'airports',
    'airlines',
    'routes',
    'trips',
    'live',
    'travellers',
    'cards',
    'profile',
    'demo',
  ];

  /// Builds a seed from raw file contents keyed by file name (no extension).
  /// `{app}` becomes the product name.
  factory Seed.fromSources(Map<String, String> raw) {
    dynamic read(String name) =>
        jsonDecode(raw[name]!.replaceAll('{app}', AppBrand.name));
    List<Map<String, dynamic>> maps(String name) =>
        (read(name) as List).cast<Map<String, dynamic>>();
    List<T> list<T>(String name, T Function(Map<String, dynamic>) f) =>
        maps(name).map(f).toList();
    final demo = read('demo') as Map<String, dynamic>;
    final routes = read('routes') as Map<String, dynamic>;
    return Seed(
      world: World(
        airports: list('airports', Airport.fromJson),
        airlines: list('airlines', Airline.fromJson),
      ),
      hubs: (routes['hubs'] as List).cast<String>(),
      popular: [
        for (final r
            in (routes['popular'] as List).cast<Map<String, dynamic>>())
          (r['from'] as String, r['to'] as String),
      ],
      trips: maps('trips'),
      live: maps('live'),
      travellers: list('travellers', Traveller.fromJson),
      cards: list('cards', PaymentCard.fromJson),
      profile: UserProfile.fromJson(read('profile') as Map<String, dynamic>),
      demoEmail: demo['demoEmail'] as String,
      wrongPassword: demo['wrongPassword'] as String,
      decliningCardLast4: demo['decliningCardLast4'] as String,
      homeAirport: demo['homeAirport'] as String,
    );
  }

  static Future<Seed> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final raw = <String, String>{};
    for (final f in files) {
      raw[f] = await b.loadString('assets/data/$f.json');
    }
    return Seed.fromSources(raw);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/airport.dart';
import '../services/account_repository.dart';
import '../services/auth_repository.dart';
import '../services/flight_repository.dart';
import '../services/seed.dart';
import '../services/store.dart';
import '../services/trip_repository.dart';

// ---------------------------------------------------------------------------
// The data switchboard.
//
// Every screen gets its data from one of the four repositories below, and
// nothing else in lib/ reads the seed. To connect a real backend, write the
// Remote* class sketched at the bottom of each repository file (they reuse
// every model's fromJson, because the seed files already use the API's JSON
// shapes) and return it here instead of the Local or Demo one. No widget,
// provider or model changes.
// ---------------------------------------------------------------------------

/// Overridden in `main` with the loaded instance, and in tests with one
/// backed by `SharedPreferences.setMockInitialValues`.
final storeProvider = Provider<Store>(
  (_) => throw UnimplementedError('storeProvider must be overridden'),
);

/// The bundled demo data. Only the Local and Demo repositories read it.
final seedProvider = FutureProvider<Seed>((_) => Seed.load());

/// The time, as a provider, so tests can stand anywhere in a flight's day.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The moment the seed's relative times are counted from: this launch, or
/// the last reset. So there is always a trip about to leave and a flight in
/// the air, whenever the app is opened.
final seedStampProvider = Provider<DateTime>(
  (ref) => ref.read(clockProvider)(),
);

final flightRepositoryProvider = FutureProvider<FlightRepository>(
  (ref) async => DemoFlightRepository(
    await ref.watch(seedProvider.future),
    clock: ref.watch(clockProvider),
    seedStamp: ref.watch(seedStampProvider),
  ),
);

final authRepositoryProvider = FutureProvider<AuthRepository>(
  (ref) async => DemoAuthRepository(await ref.watch(seedProvider.future)),
);

final accountRepositoryProvider = FutureProvider<AccountRepository>(
  (ref) async => LocalAccountRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
  ),
);

final tripRepositoryProvider = FutureProvider<TripRepository>(
  (ref) async => DemoTripRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    seedStamp: ref.watch(seedStampProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Airports and airlines by code.
final worldProvider = FutureProvider<World>(
  (ref) async => (await ref.watch(flightRepositoryProvider.future)).world(),
);

final popularRoutesProvider = FutureProvider<List<RouteDeal>>(
  (ref) async => (await ref.watch(flightRepositoryProvider.future)).popular(),
);

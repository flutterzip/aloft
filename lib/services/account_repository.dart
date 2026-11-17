import '../models/account.dart';
import 'seed.dart';
import 'store.dart';

/// The signed-in person's side of the app: their profile, the people they
/// book for and their saved cards. Async throughout, so a backend drops in without touching a
/// widget.
abstract interface class AccountRepository {
  Future<UserProfile> profile();
  Future<UserProfile> updateProfile(UserProfile profile);

  Future<List<Traveller>> travellers();

  /// Adds the traveller, or replaces the one with the same id.
  Future<Traveller> saveTraveller(Traveller traveller);
  Future<void> deleteTraveller(String id);

  Future<List<PaymentCard>> cards();
  Future<PaymentCard> saveCard(PaymentCard card);
  Future<void> deleteCard(String id);
}

/// The account on this device: the seed's person, travellers and cards until
/// they are edited, then the person's own saved copies.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this._seed, this._store);

  final Seed _seed;
  final Store _store;

  @override
  Future<UserProfile> profile() async {
    final saved = _store.json<Map<String, dynamic>>(Store.profile);
    return saved == null ? _seed.profile : UserProfile.fromJson(saved);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _store.setJson(Store.profile, profile.toJson());
    return profile;
  }

  @override
  Future<List<Traveller>> travellers() async {
    final saved = _store.json<List<dynamic>>(Store.travellers);
    if (saved == null) return _seed.travellers;
    return [
      for (final j in saved) Traveller.fromJson(j as Map<String, dynamic>),
    ];
  }

  @override
  Future<Traveller> saveTraveller(Traveller traveller) async {
    final list = await travellers();
    final exists = list.any((a) => a.id == traveller.id);
    await _store.setJson(Store.travellers, [
      for (final a in list) (a.id == traveller.id ? traveller : a).toJson(),
      if (!exists) traveller.toJson(),
    ]);
    return traveller;
  }

  @override
  Future<void> deleteTraveller(String id) async {
    await _store.setJson(Store.travellers, [
      for (final a in await travellers())
        if (a.id != id) a.toJson(),
    ]);
  }

  @override
  Future<List<PaymentCard>> cards() async {
    final saved = _store.json<List<dynamic>>(Store.cards);
    if (saved == null) return _seed.cards;
    return [
      for (final j in saved) PaymentCard.fromJson(j as Map<String, dynamic>),
    ];
  }

  @override
  Future<PaymentCard> saveCard(PaymentCard card) async {
    final list = await cards();
    final exists = list.any((c) => c.id == card.id);
    await _store.setJson(Store.cards, [
      for (final c in list) (c.id == card.id ? card : c).toJson(),
      if (!exists) card.toJson(),
    ]);
    return card;
  }

  @override
  Future<void> deleteCard(String id) async {
    await _store.setJson(Store.cards, [
      for (final c in await cards())
        if (c.id != id) c.toJson(),
    ]);
  }
}

// A network implementation. The JSON shapes match the seed files, so every
// model's fromJson is reused as it is: nothing else in the app changes.
//
// class RemoteAccountRepository implements AccountRepository {
//   RemoteAccountRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<UserProfile> profile() async =>
//       UserProfile.fromJson((await _dio.get('/me')).data);
//
//   @override
//   Future<Traveller> saveTraveller(Traveller a) async =>
//       Traveller.fromJson((await _dio.put('/me/travellers/${a.id}', data: a.toJson())).data);
//
//   // A real card is tokenised by the payment provider's SDK on the device;
//   // only the token and the display fields ever reach your server.
//   @override
//   Future<PaymentCard> saveCard(PaymentCard c) async =>
//       PaymentCard.fromJson((await _dio.post('/me/cards', data: c.toJson())).data);
//   ...
// }

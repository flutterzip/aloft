import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../services/store.dart';
import 'core_providers.dart';

/// The people the person books for, through the account repository.
class TravellersNotifier extends AsyncNotifier<List<Traveller>> {
  @override
  Future<List<Traveller>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).travellers();

  Future<void> _reload() async {
    state = AsyncData(
      await (await ref.read(accountRepositoryProvider.future)).travellers(),
    );
  }

  /// Adds [a], or replaces the traveller with the same id.
  Future<void> save(Traveller a) async {
    await (await ref.read(accountRepositoryProvider.future)).saveTraveller(a);
    await _reload();
  }

  Future<void> remove(String id) async {
    await (await ref.read(
      accountRepositoryProvider.future,
    )).deleteTraveller(id);
    await _reload();
  }
}

final travellersProvider =
    AsyncNotifierProvider<TravellersNotifier, List<Traveller>>(
      TravellersNotifier.new,
    );

/// A remembered choice of one record by id (the default card).
class ChoiceNotifier extends FamilyNotifier<String?, String> {
  @override
  String? build(String arg) => ref.watch(storeProvider).string(arg);

  Future<void> choose(String id) async {
    state = id;
    await ref.read(storeProvider).setString(arg, id);
  }
}

final _choiceProvider =
    NotifierProvider.family<ChoiceNotifier, String?, String>(
      ChoiceNotifier.new,
    );

final defaultCardIdProvider = _choiceProvider(Store.defaultCard);

/// Saved cards: brand, last four, expiry and holder, nothing more.
class CardsNotifier extends AsyncNotifier<List<PaymentCard>> {
  @override
  Future<List<PaymentCard>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).cards();

  Future<void> _reload() async {
    state = AsyncData(
      await (await ref.read(accountRepositoryProvider.future)).cards(),
    );
  }

  Future<void> save(PaymentCard c) async {
    await (await ref.read(accountRepositoryProvider.future)).saveCard(c);
    await _reload();
  }

  Future<void> remove(String id) async {
    await (await ref.read(accountRepositoryProvider.future)).deleteCard(id);
    await _reload();
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<PaymentCard>>(
  CardsNotifier.new,
);

final defaultCardProvider = Provider<PaymentCard?>((ref) {
  final list = ref.watch(cardsProvider).valueOrNull;
  if (list == null || list.isEmpty) return null;
  final id = ref.watch(defaultCardIdProvider);
  return list.firstWhere((c) => c.id == id, orElse: () => list.first);
});

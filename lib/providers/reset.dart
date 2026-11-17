import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_ref.dart';
import 'account_providers.dart';
import 'core_providers.dart';
import 'media_providers.dart';
import 'session_providers.dart';
import 'trip_providers.dart';

/// Back to a first launch: every piece of stored state goes, and the seed
/// shows through again, counted from now. Kept next to the providers so a
/// new piece of state is added here in the same change.
Future<void> resetDemoData(ProviderContainer ref) async {
  // A photo the person chose lives as a file, not in storage: delete it, or
  // the reset leaves an orphan nobody can see or reach.
  final photo = MediaRef.parse(ref.read(profileProvider).valueOrNull?.avatar);
  await ref.read(mediaStoreProvider).delete(photo);
  ref.read(pendingAvatarProvider.notifier).state = null;
  await ref.read(storeProvider).reset();
  for (final p in <ProviderOrFamily>[
    seedStampProvider,
    sessionProvider,
    profileProvider,
    themeModeProvider,
    travellersProvider,
    cardsProvider,
    defaultCardIdProvider,
    tripRepositoryProvider,
    flightRepositoryProvider,
    tripsProvider,
    trackedProvider,
    searchDraftProvider,
    recentSearchesProvider,
  ]) {
    ref.invalidate(p);
  }
}

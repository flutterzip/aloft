import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../providers/account_providers.dart';
import '../../widgets/common.dart';
import 'records.dart';
import 'traveller_sheet.dart';

/// The people the person books for: add, edit, remove.
class TravellersScreen extends ConsumerWidget {
  const TravellersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(travellersProvider).valueOrNull;
    final bottom = MediaQuery.paddingOf(context).bottom + Sizes.tabBarReserve;

    Future<void> remove(Traveller t) async {
      final yes = await confirmRemove(
        context,
        title: 'Remove ${t.name}?',
        message:
            '${t.name} will no longer be offered when you book. Trips already booked keep their seat.',
        action: 'Remove traveller',
      );
      if (!yes) return;
      await ref.read(travellersProvider.notifier).remove(t.id);
      if (context.mounted) showToast(context, '${t.name} removed');
    }

    return SubPage(
      title: 'Travellers',
      trailing: IconButton(
        key: const Key('traveller-add'),
        tooltip: 'Add a traveller',
        onPressed: () => showTravellerSheet(context),
        icon: Icon(Icons.add_rounded, color: context.palette.ink),
      ),
      child: list == null
          ? const SizedBox.expand()
          : list.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottom),
                child: EmptyState(
                  title: 'No travellers yet',
                  message:
                      'Save the people you fly with and booking takes a single tap.',
                  action: 'Add a traveller',
                  onAction: () => showTravellerSheet(context),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                bottom,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, i) {
                final t = list[i];
                return RecordCard(
                  key: ValueKey(t.id),
                  icon: Icons.person_outline_rounded,
                  title: t.name,
                  lines: 'Born ${t.born}, ${t.nationality}\n${t.masked}',
                  // Nobody is the default: who flies is chosen per booking.
                  isDefault: true,
                  showDefault: false,
                  onEdit: () => showTravellerSheet(context, existing: t),
                  onMakeDefault: () {},
                  onRemove: () => remove(t),
                );
              },
            ),
    );
  }
}

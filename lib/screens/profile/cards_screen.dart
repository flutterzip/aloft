import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../providers/account_providers.dart';
import '../../widgets/common.dart';
import 'records.dart';
import 'card_sheet.dart';

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardsProvider).valueOrNull;
    final current = ref.watch(defaultCardProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + Sizes.tabBarReserve;

    Future<void> remove(PaymentCard c) async {
      final yes = await confirmRemove(
        context,
        title: 'Remove this card?',
        message: '${c.masked} will no longer be offered when you pay.',
        action: 'Remove card',
      );
      if (!yes) return;
      await ref.read(cardsProvider.notifier).remove(c.id);
      if (context.mounted) showToast(context, '${c.masked} removed');
    }

    return SubPage(
      title: 'Payment methods',
      trailing: IconButton(
        key: const Key('card-add'),
        tooltip: 'Add a card',
        onPressed: () => showCardSheet(context),
        icon: Icon(Icons.add_rounded, color: context.palette.ink),
      ),
      child: list == null
          ? const SizedBox.expand()
          : list.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottom),
                child: EmptyState(
                  title: 'No cards yet',
                  message:
                      'Add a card to pay faster. Only its last four digits are kept.',
                  action: 'Add a card',
                  onAction: () => showCardSheet(context),
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
                final c = list[i];
                return RecordCard(
                  key: ValueKey(c.id),
                  icon: Icons.credit_card_rounded,
                  title: c.masked,
                  lines: '${c.holder}\nExpires ${c.expiry}',
                  isDefault: c.id == current?.id,
                  onMakeDefault: () =>
                      ref.read(defaultCardIdProvider.notifier).choose(c.id),
                  onRemove: () => remove(c),
                );
              },
            ),
    );
  }
}

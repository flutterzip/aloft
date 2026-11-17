import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../models/ids.dart';
import '../../providers/account_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import 'records.dart';

abstract final class CardKeys {
  static const number = Key('card-number');
  static const expiry = Key('card-expiry');
  static const holder = Key('card-holder');
  static const save = Key('card-save');
}

/// Adds a card. Resolves to the saved card.
///
/// The number is read once, to work out the brand and the last four digits,
/// and then let go. It is never stored, logged or sent anywhere, and there
/// is no security code field to keep at all: a real app collects both in
/// its payment provider's own form and receives a token.
Future<PaymentCard?> showCardSheet(BuildContext context) =>
    showAppSheet<PaymentCard>(
      context,
      title: 'New card',
      builder: (_) => const _CardForm(),
    );

/// The parts of a typed card that may be kept, or the reason it is not one.
({
  PaymentCard? card,
  String? numberError,
  String? expiryError,
  String? holderError,
})
readCard({
  required String number,
  required String expiry,
  required String holder,
  required DateTime now,
  required String id,
}) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  final numberError = digits.length < 13 || digits.length > 19
      ? 'Enter the long number on the front'
      : null;
  final m = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(expiry.trim());
  final month = int.tryParse(m?.group(1) ?? '');
  final year = m == null ? null : 2000 + int.parse(m.group(2)!);
  String? expiryError;
  if (month == null || year == null || month < 1 || month > 12) {
    expiryError = 'Use MM/YY';
  } else if (year < now.year || (year == now.year && month < now.month)) {
    expiryError = 'This card has expired';
  }
  final holderError = holder.trim().length < 2
      ? 'Enter the name on the card'
      : null;
  if (numberError != null || expiryError != null || holderError != null) {
    return (
      card: null,
      numberError: numberError,
      expiryError: expiryError,
      holderError: holderError,
    );
  }
  return (
    card: PaymentCard(
      id: id,
      brand: PaymentCard.brandOf(digits),
      last4: digits.substring(digits.length - 4),
      expMonth: month!,
      expYear: year!,
      holder: holder.trim(),
    ),
    numberError: null,
    expiryError: null,
    holderError: null,
  );
}

class _CardForm extends ConsumerStatefulWidget {
  const _CardForm();

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  late final _holder = TextEditingController(
    text: ref.read(profileProvider).valueOrNull?.name ?? '',
  );
  String? _numberError, _expiryError, _holderError, _problem;
  bool _busy = false;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final read = readCard(
      number: _number.text,
      expiry: _expiry.text,
      holder: _holder.text,
      now: ref.read(clockProvider)(),
      id: Ids.next('c'),
    );
    setState(() {
      _numberError = read.numberError;
      _expiryError = read.expiryError;
      _holderError = read.holderError;
      _problem = null;
    });
    final card = read.card;
    if (card == null) return;
    setState(() => _busy = true);
    try {
      await AppTiming.atLeast(
        AppTiming.saveForm,
        ref.read(cardsProvider.notifier).save(card),
      );
      // The typed number has done its job.
      _number.clear();
      if (mounted) Navigator.of(context).pop(card);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'Could not save that card. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            fieldKey: CardKeys.number,
            label: 'Card number',
            controller: _number,
            hint: '1234 5678 9012 3456',
            icon: Icons.credit_card_rounded,
            error: _numberError,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              const _Grouped(4, ' '),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppField(
                  fieldKey: CardKeys.expiry,
                  label: 'Expiry',
                  controller: _expiry,
                  hint: 'MM/YY',
                  error: _expiryError,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    const _Grouped(2, '/'),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                flex: 3,
                child: AppField(
                  fieldKey: CardKeys.holder,
                  label: 'Name on card',
                  controller: _holder,
                  hint: 'As printed',
                  error: _holderError,
                  capitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          const Notice(
            'Only the last four digits are kept on this device.',
            icon: Icons.lock_outline_rounded,
          ),
          if (_problem != null) ...[
            const SizedBox(height: Space.sm),
            Notice(_problem!, error: true),
          ],
          const SizedBox(height: Space.lg),
          KeyedSubtree(
            key: CardKeys.save,
            child: PrimaryButton(
              label: 'Save card',
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inserts [separator] after every [size] digits as they are typed.
class _Grouped extends TextInputFormatter {
  const _Grouped(this.size, this.separator);

  final int size;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text;
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % size == 0) out.write(separator);
      out.write(digits[i]);
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Chooses how to pay. Resolves to the chosen card's id.
Future<String?> showCardPicker(BuildContext context, {String? selected}) =>
    showAppSheet<String>(
      context,
      title: 'Pay with',
      builder: (_) => _CardPicker(selected: selected),
    );

class _CardPicker extends ConsumerWidget {
  const _CardPicker({this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardsProvider).valueOrNull ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Text('No cards saved yet.', style: context.body),
            ),
          for (final c in list)
            PickRow(
              title: c.masked,
              subtitle: '${c.holder}, expires ${c.expiry}',
              selected: c.id == selected,
              onTap: () => Navigator.of(context).pop(c.id),
            ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            quiet: true,
            icon: Icons.add_rounded,
            label: 'Add a card',
            onPressed: () async {
              final added = await showCardSheet(context);
              if (added != null && context.mounted) {
                Navigator.of(context).pop(added.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

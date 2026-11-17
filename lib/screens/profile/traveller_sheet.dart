import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../models/account.dart';
import '../../models/ids.dart';
import '../../providers/account_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/primary_button.dart';

abstract final class TravellerKeys {
  static const name = Key('traveller-name');
  static const born = Key('traveller-born');
  static const nationality = Key('traveller-nationality');
  static const passport = Key('traveller-passport');
  static const save = Key('traveller-save');
}

/// Adds a traveller, or edits [existing]. Resolves to the saved traveller.
Future<Traveller?> showTravellerSheet(
  BuildContext context, {
  Traveller? existing,
}) => showAppSheet<Traveller>(
  context,
  title: existing == null ? 'Add a traveller' : 'Edit traveller',
  builder: (_) => _TravellerForm(existing: existing),
);

class _TravellerForm extends ConsumerStatefulWidget {
  const _TravellerForm({this.existing});

  final Traveller? existing;

  @override
  ConsumerState<_TravellerForm> createState() => _TravellerFormState();
}

class _TravellerFormState extends ConsumerState<_TravellerForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _born = TextEditingController(
    text: widget.existing?.born.toString(),
  );
  late final _nationality = TextEditingController(
    text: widget.existing?.nationality,
  );
  late final _passport = TextEditingController(text: widget.existing?.passport);
  String? _nameError, _bornError, _nationalityError, _passportError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _born.dispose();
    _nationality.dispose();
    _passport.dispose();
    super.dispose();
  }

  String? _checkBorn(String v) {
    final year = int.tryParse(v);
    final now = ref.read(clockProvider)().year;
    if (year == null) return 'Enter a year, such as 1994.';
    if (year < now - 120 || year > now) return 'That year does not look right.';
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _nameError = _name.text.trim().length < 2
          ? 'Enter the name as it is on the passport.'
          : null;
      _bornError = _checkBorn(_born.text.trim());
      _nationalityError = _nationality.text.trim().isEmpty
          ? 'Enter a nationality.'
          : null;
      final pass = _passport.text.trim();
      _passportError = pass.isNotEmpty && pass.length != 4
          ? 'Enter the last 4 characters, or leave it empty.'
          : null;
    });
    if ([
      _nameError,
      _bornError,
      _nationalityError,
      _passportError,
    ].any((e) => e != null)) {
      return;
    }
    setState(() => _saving = true);
    final traveller = Traveller(
      id: widget.existing?.id ?? Ids.next('tr'),
      name: _name.text.trim(),
      born: int.parse(_born.text.trim()),
      nationality: _nationality.text.trim(),
      passport: _passport.text.trim().toUpperCase(),
    );
    await AppTiming.atLeast(
      AppTiming.saveForm,
      ref.read(travellersProvider.notifier).save(traveller),
    );
    if (mounted) Navigator.of(context).pop(traveller);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.md,
            ),
            child: Column(
              children: [
                AppField(
                  fieldKey: TravellerKeys.name,
                  label: 'Full name',
                  controller: _name,
                  hint: 'As it is on the passport',
                  icon: Icons.person_outline_rounded,
                  error: _nameError,
                  capitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppField(
                        fieldKey: TravellerKeys.born,
                        label: 'Year of birth',
                        controller: _born,
                        hint: '1994',
                        icon: Icons.cake_outlined,
                        error: _bornError,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppField(
                        fieldKey: TravellerKeys.passport,
                        label: 'Passport, last 4',
                        controller: _passport,
                        hint: 'Optional',
                        icon: Icons.badge_outlined,
                        error: _passportError,
                        capitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                AppField(
                  fieldKey: TravellerKeys.nationality,
                  label: 'Nationality',
                  controller: _nationality,
                  hint: 'Country of the passport',
                  icon: Icons.public_rounded,
                  error: _nationalityError,
                  capitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
        ),
        // Pinned: the form scrolls, the action does not.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.lg,
          ),
          child: KeyedSubtree(
            key: TravellerKeys.save,
            child: PrimaryButton(
              label: widget.existing == null ? 'Add traveller' : 'Save changes',
              busy: _saving,
              onPressed: _save,
            ),
          ),
        ),
      ],
    );
  }
}

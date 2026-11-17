import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/airport.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';

typedef Party = ({int adults, Cabin cabin});

/// The most seats one booking can hold.
const maxTravellers = 4;

/// How many are flying, and in which cabin.
Future<Party?> showPartySheet(
  BuildContext context, {
  required int adults,
  required Cabin cabin,
}) => showAppSheet<Party>(
  context,
  title: 'Travellers and cabin',
  builder: (_) => _PartySheet(adults: adults, cabin: cabin),
);

class _PartySheet extends StatefulWidget {
  const _PartySheet({required this.adults, required this.cabin});

  final int adults;
  final Cabin cabin;

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  late int _adults = widget.adults;
  late Cabin _cabin = widget.cabin;

  void _step(int by) {
    HapticFeedback.selectionClick();
    setState(() => _adults = (_adults + by).clamp(1, maxTravellers));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Travellers', style: context.title),
                    Text(
                      _adults == maxTravellers
                          ? 'Up to $maxTravellers on one booking'
                          : 'Everyone with a seat',
                      style: context.caption,
                    ),
                  ],
                ),
              ),
              RoundIcon(
                key: const Key('party-less'),
                icon: Icons.remove_rounded,
                label: 'One fewer traveller',
                filled: true,
                onTap: _adults > 1 ? () => _step(-1) : null,
                color: _adults > 1 ? p.ink : p.line,
              ),
              SizedBox(
                width: 34,
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Text(
                    '$_adults',
                    key: ValueKey(_adults),
                    textAlign: TextAlign.center,
                    style: context.heading,
                  ),
                ),
              ),
              RoundIcon(
                key: const Key('party-more'),
                icon: Icons.add_rounded,
                label: 'One more traveller',
                filled: true,
                onTap: _adults < maxTravellers ? () => _step(1) : null,
                color: _adults < maxTravellers ? p.ink : p.line,
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('CABIN', style: context.label.copyWith(color: p.muted)),
          const SizedBox(height: Space.sm),
          for (final c in Cabin.values)
            Semantics(
              button: true,
              selected: c == _cabin,
              label: c.label,
              excludeSemantics: true,
              child: InkWell(
                key: Key('cabin-${c.name}'),
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _cabin = c);
                },
                child: AnimatedContainer(
                  duration: Motion.quick,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: c == _cabin ? p.accentWash : null,
                    border: Border.all(color: c == _cabin ? p.accent : p.line),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.label, style: context.title)),
                      if (c == _cabin)
                        Icon(Icons.check_rounded, size: 20, color: p.accent),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            key: const Key('party-done'),
            label: 'Done',
            onPressed: () =>
                Navigator.of(context).pop((adults: _adults, cabin: _cabin)),
          ),
        ],
      ),
    );
  }
}

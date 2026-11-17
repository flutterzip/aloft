import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../widgets/flight_loader.dart';

/// "I agree to the terms": a box that ticks, with the whole row tappable.
class TermsCheck extends StatelessWidget {
  const TermsCheck({super.key, required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: checked,
      label: 'I agree to the terms and the privacy policy',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.quick,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? p.accent : null,
                  border: Border.all(
                    color: checked ? p.accent : p.muted,
                    width: 1.4,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: checked
                    ? Icon(Icons.check_rounded, size: 16, color: p.onAccent)
                    : null,
              ),
              const SizedBox(width: Space.md),
              Flexible(
                child: Text(
                  'I agree to the terms and the privacy policy',
                  style: context.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the form becomes once the sign-in has gone through: the plane
/// circling the logo while the trips load.
class BoardingNotice extends StatelessWidget {
  const BoardingNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 56, bottom: 120),
    child: Column(
      children: [
        const FlightLoader(size: 150),
        const SizedBox(height: Space.xl),
        Text('Getting your trips ready', style: context.heading),
        const SizedBox(height: 6),
        Text('Boarding passes, seats and gates', style: context.body),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/money.dart';
import '../../models/when.dart';

/// Nine days around the search with the lowest fare on each. The chosen
/// day carries the accent; a day with nothing left says so.
class FareStrip extends StatelessWidget {
  const FareStrip({
    super.key,
    required this.selected,
    required this.fares,
    required this.onPick,
  });

  final DateTime selected;
  final Map<DateTime, int> fares;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = fares.keys.toList()..sort();
    if (days.isEmpty) return const SizedBox(height: 78);
    final cheapest = fares.values.reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.md,
        ),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final day = days[i];
          final on = When.sameDay(day, selected);
          final fare = fares[day]!;
          return Semantics(
            button: true,
            selected: on,
            label: '${When.day(day)}, from ${money(fare)}',
            excludeSemantics: true,
            child: GestureDetector(
              key: Key('fare-${When.iso(day)}'),
              onTap: () => onPick(day),
              child: AnimatedContainer(
                duration: Motion.short,
                curve: Motion.settle,
                width: 70,
                decoration: BoxDecoration(
                  color: on ? p.accent : p.card,
                  border: Border.all(color: on ? p.accent : p.line),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${When.weekday(day)} ${day.day}',
                        style: context.caption.copyWith(
                          fontSize: 11.5,
                          color: on ? p.onAccent : p.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        money(fare),
                        style: context.price.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: on
                              ? p.onAccent
                              : fare == cheapest
                              ? p.accent
                              : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

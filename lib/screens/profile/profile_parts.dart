import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../providers/session_providers.dart';
import '../../providers/trip_providers.dart';

/// What has been flown, counted from past trips: the numbers tick up from
/// zero the first time they are seen.
class TravelStatsCard extends StatelessWidget {
  const TravelStatsCard({super.key, required this.stats, required this.member});

  final TravelStats stats;
  final String member;

  static String _thousands(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget cell(String label, int value) => Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: Motion.reduced(context) ? Duration.zero : Motion.entrance,
            curve: Motion.settle,
            builder: (context, v, _) => Text(
              _thousands(v.round()),
              style: context.price.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.caption),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Space.lg,
        horizontal: Space.sm,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              cell('Flights', stats.flights),
              Container(width: 1, height: 34, color: p.line),
              cell('Kilometres', stats.km),
              Container(width: 1, height: 34, color: p.line),
              cell('Countries', stats.countries),
            ],
          ),
          if (member.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text(
              'MEMBER $member',
              style: context.label.copyWith(color: p.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(color: p.line, indent: 52),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: Space.lg),
              Icon(icon, size: 20, color: p.ink),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
              ),
              if (value != null) Text(value!, style: context.caption),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
              const SizedBox(width: Space.md),
            ],
          ),
        ),
      ),
    );
  }
}

class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({super.key});

  static const _modes = [
    (ThemeMode.system, 'Auto'),
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final current = ref.watch(themeModeProvider);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: [
          for (final (mode, label) in _modes)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == current,
                label: '$label appearance',
                excludeSemantics: true,
                child: GestureDetector(
                  key: Key('appearance-${mode.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).set(mode);
                  },
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode == current ? p.card : null,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: mode == current
                          ? Border.all(color: p.line)
                          : null,
                    ),
                    child: Text(
                      label,
                      style: context.title.copyWith(
                        fontSize: 13.5,
                        color: mode == current ? p.ink : p.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

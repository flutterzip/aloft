import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../config/motion.dart';

/// A row of choices with a thumb that slides to the chosen one.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.caption,
    this.height = 44,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  /// A small second line under each label, such as a count.
  final String Function(T)? caption;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = values.indexOf(value);
    final n = values.length;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Motion.short,
            curve: Motion.settle,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: v == value,
                    label: label(v),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: ValueKey('segment-${label(v)}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (v == value) return;
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: Motion.quick,
                            style: context.title.copyWith(
                              fontSize: 13.5,
                              color: v == value ? p.ink : p.muted,
                            ),
                            child: Text(
                              label(v),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (caption != null)
                            Text(
                              caption!(v),
                              maxLines: 1,
                              style: context.caption.copyWith(fontSize: 10.5),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

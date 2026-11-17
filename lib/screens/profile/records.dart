import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/primary_button.dart';

/// A record in a managed list (a traveller, a card): what it is, whether it
/// is the default, and the ways to change it.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.isDefault,
    required this.onMakeDefault,
    required this.onRemove,
    this.onEdit,
    this.showDefault = true,
  });

  final IconData icon;
  final String title;
  final String lines;
  final bool isDefault;
  final VoidCallback onMakeDefault;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  /// False for lists with no default: the tag and the outline are left off.
  final bool showDefault;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget link(String text, VoidCallback onTap, {Color? color}) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color ?? p.ink,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(
          fontFamily: AppTheme.font,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      child: Text(text),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, 6, 4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: isDefault && showDefault ? p.ink : p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: p.ink),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.title,
                          ),
                        ),
                        if (isDefault && showDefault) ...[
                          const SizedBox(width: Space.sm),
                          const Tag('DEFAULT'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(lines, style: context.caption),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            children: [
              if (onEdit != null) link('Edit', onEdit!),
              if (!isDefault) link('Make default', onMakeDefault),
              link('Remove', onRemove, color: p.error),
            ],
          ),
        ],
      ),
    );
  }
}

/// A confirmation whose button names what it does. Resolves true to go on.
Future<bool> confirmRemove(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showAppSheet<bool>(
      context,
      title: title,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: context.body),
            const SizedBox(height: Space.xl),
            KeyedSubtree(
              key: const Key('confirm-remove'),
              child: PrimaryButton(
                label: action,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              quiet: true,
              label: 'Keep it',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ) ??
    false;

/// A selectable row in a picker sheet: a title, some detail, a radio mark.
class PickRow extends StatelessWidget {
  const PickRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? p.ink : null,
                  border: Border.all(
                    color: selected ? p.ink : p.muted,
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: p.paper)
                    : null,
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.title),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.caption),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.md),
                Text(trailing!, style: context.price),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small quiet tag: "DEFAULT".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.label.copyWith(
          fontSize: 8.5,
          letterSpacing: 1.2,
          color: p.inkSoft,
        ),
      ),
    );
  }
}

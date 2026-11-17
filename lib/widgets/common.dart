import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/app_timing.dart';
import '../config/design_tokens.dart';
import '../config/palette.dart';
import 'route_arc.dart';

/// A page pushed inside a tab: an opaque ground (so the page beneath never
/// shows through the transition), a back button and a title.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // The app's status bar is light for the sky; a plain page sets its own.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: _page(context, p),
    );
  }

  Widget _page(BuildContext context, Palette p) {
    return Material(
      color: p.paper,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 6),
                BackChevron(onTap: onBack),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.heading,
                  ),
                ),
                ?trailing,
                const SizedBox(width: Space.md),
              ],
            ),
          ),
          Divider(color: p.line),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class BackChevron extends StatelessWidget {
  const BackChevron({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onTap ?? () => Navigator.of(context).maybePop(),
    icon: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 18,
      color: context.palette.ink,
    ),
  );
}

/// A round icon button with a 44dp target.
class RoundIcon extends StatelessWidget {
  const RoundIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
    this.size = 18,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: filled ? p.card : null,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: size, color: color ?? p.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty states name the situation and show the plane, never a stock icon.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 74,
            child: RouteArc(
              progress: const AlwaysStoppedAnimation(.62),
              line: p.line,
              flown: p.muted,
              plane: p.accent,
              planeSize: 26,
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(title, style: context.heading, textAlign: TextAlign.center),
          const SizedBox(height: Space.sm),
          Text(message, style: context.body, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: Space.xl),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl,
                  vertical: Space.md,
                ),
                shape: StadiumBorder(side: BorderSide(color: p.ink)),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small pill naming a state: "Boarding", "Delayed 45m", "Non-stop".
/// [live] puts it in the accent with a dot; [error] in the error colour.
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.text, {
    super.key,
    this.live = false,
    this.error = false,
    this.onSky = false,
  });

  final String text;
  final bool live;
  final bool error;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = error
        ? p.error
        : live
        ? p.accent
        : (onSky ? p.onSky : p.inkSoft);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: onSky
            ? p.onSky.withValues(alpha: .12)
            : live
            ? p.accentWash
            : error
            ? p.error.withValues(alpha: .1)
            : p.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live || error) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's title with an optional action at its right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.xl,
      Space.sm,
      Space.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.heading,
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: context.palette.accent,
              textStyle: const TextStyle(
                fontFamily: AppTheme.font,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            child: Text(action!),
          )
        else
          const SizedBox(width: Space.md, height: 48),
      ],
    ),
  );
}

/// A still grey block standing in for content that is loading.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 120, this.radius = Radii.xl});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: context.palette.field,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// A one-line notice: an icon and a sentence, sized to the sentence.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.icon, this.error = false});

  final String text;
  final IconData? icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = error ? p.error : p.inkSoft;
    return Row(
      children: [
        Icon(
          icon ??
              (error
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded),
          size: 16,
          color: tone,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: context.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of a label and a value, as on a receipt.
class ReceiptRow extends StatelessWidget {
  const ReceiptRow(this.label, this.value, {super.key, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: strong ? context.title : context.body,
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            value,
            style: context.price.copyWith(
              fontSize: strong ? 17 : 14,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet floating confirmation, with an optional "Undo".
void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  VoidCallback? onUndo,
  VoidCallback? onClosed,
}) => showToastOn(
  ScaffoldMessenger.of(context),
  context.palette,
  message,
  icon: icon,
  onUndo: onUndo,
  onClosed: onClosed,
);

void showToastOn(
  ScaffoldMessengerState messenger,
  Palette p,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  VoidCallback? onUndo,
  VoidCallback? onClosed,
}) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      duration: onUndo == null
          ? const Duration(milliseconds: 1800)
          : AppTiming.undoWindow,
      // A SnackBar with an action stays until it is tapped unless told
      // otherwise; an "Undo" is only on offer for the undo window.
      persist: false,
      // Clear of the floating tab bar, and of a page's pinned button above
      // it: an "Undo" must never sit on top of an action.
      margin: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Sizes.tabBarReserve + Sizes.buttonHeight - 6,
      ),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'Undo', onPressed: onUndo),
      content: Row(
        children: [
          Icon(icon, color: p.paper, size: 19),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
  if (onClosed != null) controller.closed.then((_) => onClosed());
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/when.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';

typedef TravelDates = ({DateTime depart, DateTime? back});

/// Picks the day to fly, and for a return the day to come back: the first
/// tap is the way out, the second the way home. Days before [today] cannot
/// be picked.
Future<TravelDates?> showDateSheet(
  BuildContext context, {
  required DateTime today,
  required DateTime depart,
  DateTime? back,
  required bool roundTrip,
}) => showAppSheet<TravelDates>(
  context,
  title: roundTrip ? 'When are you travelling?' : 'When are you flying?',
  builder: (_) => _DateSheet(
    today: today,
    depart: depart,
    back: back,
    roundTrip: roundTrip,
  ),
);

class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.today,
    required this.depart,
    required this.back,
    required this.roundTrip,
  });

  final DateTime today;
  final DateTime depart;
  final DateTime? back;
  final bool roundTrip;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _depart = widget.depart;
  late DateTime? _back = widget.back;
  late DateTime _month = DateTime(widget.depart.year, widget.depart.month);

  /// In a return, whether the next tap sets the way home.
  bool _pickingBack = false;

  /// Which way the month last turned, so the grid slides the right way.
  int _turn = 1;

  DateTime get _firstMonth => DateTime(widget.today.year, widget.today.month);
  DateTime get _lastMonth =>
      DateTime(widget.today.year, widget.today.month + 11);

  void _page(int by) => setState(() {
    _turn = by;
    _month = DateTime(_month.year, _month.month + by);
  });

  void _tap(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!widget.roundTrip) {
        _depart = day;
      } else if (_pickingBack && !day.isBefore(_depart)) {
        _back = day;
        _pickingBack = false;
      } else {
        _depart = day;
        _back = null;
        _pickingBack = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final needsBack = widget.roundTrip && _back == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(
            children: [
              RoundIcon(
                icon: Icons.chevron_left_rounded,
                label: 'Earlier month',
                size: 24,
                onTap: _month.isAfter(_firstMonth) ? () => _page(-1) : null,
                color: _month.isAfter(_firstMonth) ? p.ink : p.line,
              ),
              Expanded(
                child: Text(
                  '${When.monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: context.title.copyWith(fontSize: 16),
                ),
              ),
              RoundIcon(
                icon: Icons.chevron_right_rounded,
                label: 'Later month',
                size: 24,
                onTap: _month.isBefore(_lastMonth) ? () => _page(1) : null,
                color: _month.isBefore(_lastMonth) ? p.ink : p.line,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: context.caption)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: AnimatedSwitcher(
            duration: Motion.short,
            switchInCurve: Motion.enter,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(
                    child.key == ValueKey(_month) ? .12 * _turn : -.12 * _turn,
                    0,
                  ),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: _MonthGrid(
              key: ValueKey(_month),
              month: _month,
              today: widget.today,
              depart: _depart,
              back: _back,
              onTap: _tap,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.lg,
          ),
          child: PrimaryButton(
            key: const Key('date-done'),
            label: needsBack
                ? 'Now pick the day you come back'
                : widget.roundTrip
                ? '${When.day(_depart)} to ${When.day(_back!)}'
                : 'Fly on ${When.day(_depart)}',
            // Stays pressable: pressing it early says what is missing.
            onPressed: () {
              if (needsBack) {
                setState(() => _pickingBack = true);
                HapticFeedback.heavyImpact();
                return;
              }
              Navigator.of(context).pop((depart: _depart, back: _back));
            },
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.depart,
    required this.back,
    required this.onTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime depart;
  final DateTime? back;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lead = DateTime(month.year, month.month).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return Column(
      children: [
        // Always six rows, so the sheet does not change height by month.
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final n = row * 7 + col - lead + 1;
                      if (n < 1 || n > days) return const SizedBox(height: 46);
                      final day = DateTime(month.year, month.month, n);
                      final past = day.isBefore(today);
                      final isDepart = When.sameDay(day, depart);
                      final isBack = back != null && When.sameDay(day, back!);
                      final between =
                          back != null &&
                          day.isAfter(depart) &&
                          day.isBefore(back!);
                      final end = isDepart || isBack;
                      return Semantics(
                        button: true,
                        enabled: !past,
                        selected: end,
                        label: When.day(day),
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: Key('day-${When.iso(day)}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: past ? null : () => onTap(day),
                          child: SizedBox(
                            height: 46,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // The band joining the two days of a return.
                                if (back != null && (between || end))
                                  Positioned.fill(
                                    top: 5,
                                    bottom: 5,
                                    left: isDepart ? 23 : 0,
                                    right: isBack ? 23 : 0,
                                    child: ColoredBox(color: p.accentWash),
                                  ),
                                AnimatedContainer(
                                  duration: Motion.quick,
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: end ? p.accent : null,
                                    shape: BoxShape.circle,
                                    border: When.sameDay(day, today) && !end
                                        ? Border.all(color: p.muted)
                                        : null,
                                  ),
                                  child: Text(
                                    '$n',
                                    style: context.title.copyWith(
                                      fontWeight: end
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: end
                                          ? p.onAccent
                                          : past
                                          ? p.line
                                          : p.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

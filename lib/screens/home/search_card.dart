import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/airport.dart';
import '../../models/flight.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/plane.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented.dart';
import '../actions.dart';
import 'airport_sheet.dart';
import 'date_sheet.dart';
import 'party_sheet.dart';

abstract final class SearchKeys {
  static const from = Key('search-from');
  static const to = Key('search-to');
  static const swap = Key('search-swap');
  static const depart = Key('search-depart');
  static const back = Key('search-return');
  static const party = Key('search-party');
  static const submit = Key('search-submit');
}

/// The search form: one way or return, the two airports with a swap
/// between them, the dates, who is flying and in which cabin.
class SearchCard extends ConsumerStatefulWidget {
  const SearchCard({super.key});

  @override
  ConsumerState<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends ConsumerState<SearchCard> {
  /// Half turns of the swap button; it keeps turning the same way.
  int _turns = 0;

  SearchDraftNotifier get _draft => ref.read(searchDraftProvider.notifier);

  Future<void> _pickAirport({required bool from}) async {
    final q = ref.read(searchDraftProvider);
    final picked = await showAirportSheet(
      context,
      title: from ? 'Flying from' : 'Flying to',
      current: from ? q.from : q.to,
      other: from ? q.to : q.from,
    );
    if (picked == null) return;
    _draft.set(
      from ? q.copyWith(from: picked.code) : q.copyWith(to: picked.code),
    );
  }

  Future<void> _pickDates({bool addReturn = false}) async {
    final q = ref.read(searchDraftProvider);
    final roundTrip = q.roundTrip || addReturn;
    final picked = await showDateSheet(
      context,
      today: When.dateOnly(ref.read(clockProvider)()),
      depart: q.date,
      back: q.returnDate,
      roundTrip: roundTrip,
    );
    if (picked == null) return;
    _draft.set(
      SearchQuery(
        from: q.from,
        to: q.to,
        date: picked.depart,
        returnDate: picked.back,
        adults: q.adults,
        cabin: q.cabin,
      ),
    );
  }

  Future<void> _pickParty() async {
    final q = ref.read(searchDraftProvider);
    final picked = await showPartySheet(
      context,
      adults: q.adults,
      cabin: q.cabin,
    );
    if (picked == null) return;
    _draft.set(q.copyWith(adults: picked.adults, cabin: picked.cabin));
  }

  void _setRoundTrip(bool roundTrip) {
    final q = ref.read(searchDraftProvider);
    _draft.set(
      roundTrip
          ? q.copyWith(returnDate: q.date.add(const Duration(days: 7)))
          : q.copyWith(oneWay: true),
    );
  }

  void _swap() {
    HapticFeedback.mediumImpact();
    setState(() => _turns++);
    _draft.swap();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = ref.watch(searchDraftProvider);
    final world = ref.watch(worldProvider).valueOrNull;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.xl + 4),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<bool>(
            values: const [false, true],
            value: q.roundTrip,
            label: (r) => r ? 'Return' : 'One way',
            onChanged: _setRoundTrip,
          ),
          const SizedBox(height: Space.md),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AirportBox(
                      key: SearchKeys.from,
                      label: 'From',
                      airport: world?.maybeAirport(q.from),
                      code: q.from,
                      alignEnd: false,
                      onTap: () => _pickAirport(from: true),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _AirportBox(
                      key: SearchKeys.to,
                      label: 'To',
                      airport: world?.maybeAirport(q.to),
                      code: q.to,
                      alignEnd: true,
                      onTap: () => _pickAirport(from: false),
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: 'Swap the two airports',
                excludeSemantics: true,
                child: Pressable(
                  key: SearchKeys.swap,
                  scale: .86,
                  onTap: _swap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.card, width: 4),
                    ),
                    child: AnimatedRotation(
                      turns: _turns / 2,
                      duration: Motion.medium,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 20,
                        color: p.onAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _Field(
                  key: SearchKeys.depart,
                  icon: Icons.calendar_today_rounded,
                  label: 'Departure',
                  value: When.day(q.date),
                  onTap: _pickDates,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _Field(
                  key: SearchKeys.back,
                  icon: Icons.event_repeat_rounded,
                  label: 'Return',
                  value: q.returnDate == null
                      ? 'Add a return'
                      : When.day(q.returnDate!),
                  quiet: q.returnDate == null,
                  onTap: () => _pickDates(addReturn: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          _Field(
            key: SearchKeys.party,
            icon: Icons.airline_seat_recline_normal_rounded,
            label: 'Travellers and cabin',
            value:
                '${q.adults} ${q.adults == 1 ? 'traveller' : 'travellers'}, ${q.cabin.label}',
            onTap: _pickParty,
          ),
          const SizedBox(height: Space.md),
          _SearchButton(onPressed: () => runSearch(context, q)),
        ],
      ),
    );
  }
}

/// The primary button with the plane on it: pressing sends the plane off
/// the right edge before the results open.
class _SearchButton extends StatefulWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _away;

  @override
  void initState() {
    super.initState();
    _away = AnimationController(vsync: this, duration: Motion.medium);
  }

  @override
  void dispose() {
    _away.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_away.isAnimating) return;
    if (Motion.loops(context)) await _away.forward();
    if (!mounted) return;
    widget.onPressed();
    _away.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        PrimaryButton(
          key: SearchKeys.submit,
          label: 'Search flights',
          onPressed: _go,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: AnimatedBuilder(
                animation: _away,
                builder: (context, child) {
                  final t = Curves.easeInCubic.transform(_away.value);
                  return Align(
                    alignment: Alignment(-.86 + 2.4 * t, -.5 * t),
                    child: Transform.rotate(angle: -.35 * t, child: child),
                  );
                },
                child: PlaneIcon(color: p.onAccent, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AirportBox extends StatelessWidget {
  const _AirportBox({
    super.key,
    required this.label,
    required this.airport,
    required this.code,
    required this.alignEnd,
    required this.onTap,
  });

  final String label;
  final Airport? airport;
  final String code;
  final bool alignEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Semantics(
      button: true,
      label: '$label ${airport?.city ?? code}, $code',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: .97,
        child: Container(
          height: 112,
          padding: EdgeInsets.fromLTRB(
            alignEnd ? 26 : Space.lg,
            Space.md,
            alignEnd ? Space.lg : 26,
            Space.md,
          ),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: x,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: context.caption),
              // The code slides in from the side it came from when swapped.
              AnimatedSwitcher(
                duration: Motion.short,
                switchInCurve: Motion.enter,
                layoutBuilder: (current, previous) => Stack(
                  alignment: alignEnd
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(alignEnd ? -.5 : .5, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: Text(code, key: ValueKey(code), style: context.code),
              ),
              const SizedBox(height: 3),
              Text(
                airport?.city ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.title.copyWith(fontSize: 13.5),
              ),
              Text(
                airport?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.quiet = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Nothing chosen yet: the value reads as an invitation.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: .97,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: quiet ? p.muted : p.ink),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(fontSize: 11),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title.copyWith(
                        fontSize: 14,
                        color: quiet ? p.muted : p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

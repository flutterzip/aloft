import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/flight.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/removable.dart';
import '../../widgets/sky_scene.dart';
import '../home/home_tab.dart' show SkyBackdrop;
import 'status_card.dart';

abstract final class StatusKeys {
  static const field = Key('status-field');
  static const find = Key('status-find');
  static const follow = Key('status-follow');
}

/// Every outcome of looking a flight up, named, so the screen shows each.
sealed class Lookup {
  const Lookup();
}

class LookupIdle extends Lookup {
  const LookupIdle();
}

class LookupEmpty extends Lookup {
  const LookupEmpty();
}

class LookupFound extends Lookup {
  const LookupFound(this.flight);
  final Flight flight;
}

class LookupNotFound extends Lookup {
  const LookupNotFound(this.code);
  final String code;
}

/// Status: look a flight up by its number, and follow the ones that matter.
/// Each followed flight shows its plane where it really is on its path.
class StatusTab extends ConsumerStatefulWidget {
  const StatusTab({super.key});

  @override
  ConsumerState<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends ConsumerState<StatusTab> {
  final _scroll = ScrollController();
  final _code = TextEditingController();
  Lookup _lookup = const LookupIdle();
  bool _looking = false;

  /// Flights just unfollowed, kept on the page while their undo is on
  /// offer, with the place each one held.
  final _leaving = <String, (Flight, int)>{};

  @override
  void dispose() {
    _scroll.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final code = normaliseFlightCode(_code.text);
    if (code.isEmpty) {
      setState(() => _lookup = const LookupEmpty());
      return;
    }
    setState(() => _looking = true);
    final live = await AppTiming.atLeast(
      AppTiming.lookUp,
      ref.read(liveFlightsProvider.future),
    );
    if (!mounted) return;
    Flight? found;
    for (final f in live) {
      if (normaliseFlightCode(f.code) == code) found = f;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _looking = false;
      _lookup = found == null
          ? LookupNotFound(_code.text.trim().toUpperCase())
          : LookupFound(found);
    });
  }

  Future<void> _unfollow(Flight f) async {
    final tracked = ref.read(trackedProvider);
    final at = tracked.indexOf(normaliseFlightCode(f.code));
    final notifier = ref.read(trackedProvider.notifier);
    setState(() => _leaving[f.id] = (f, at));
    await notifier.remove(f.code);
    if (!mounted) return;
    showToast(
      context,
      'Stopped following ${f.code}',
      onUndo: () {
        notifier.add(f.code, at: at);
        if (mounted) setState(() => _leaving.remove(f.id));
      },
      onClosed: () {
        if (mounted) setState(() => _leaving.remove(f.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final tracked = ref.watch(trackedFlightsProvider);
    final codes = ref.watch(trackedProvider);
    // Followed flights, with the ones on their way out held in place.
    final rows = [...tracked];
    for (final (f, at) in _leaving.values) {
      if (!rows.any((r) => r.id == f.id)) {
        rows.insert(at.clamp(0, rows.length), f);
      }
    }
    final lookup = _lookup;

    return Material(
      color: p.paper,
      child: Stack(
        children: [
          SkyBackdrop(controller: _scroll),
          ListView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              bottom: media.padding.bottom + Sizes.tabBarReserve,
            ),
            children: [
              Stack(
                children: [
                  const SkyHeader(height: 150, sun: Alignment(.2, 1.1)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      media.padding.top + 18,
                      Space.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Flight status',
                          style: context.display.copyWith(color: p.onSky),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Any flight today, by its number',
                          style: context.body.copyWith(color: p.onSkyMuted),
                        ),
                        const SizedBox(height: Space.xl),
                        Container(
                          padding: const EdgeInsets.all(Space.md),
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
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: Sizes.buttonHeight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.lg,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: p.field,
                                    borderRadius: BorderRadius.circular(
                                      Radii.pill,
                                    ),
                                  ),
                                  child: TextField(
                                    key: StatusKeys.field,
                                    controller: _code,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) => _find(),
                                    style: context.title.copyWith(fontSize: 16),
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      hintText: 'HC 318',
                                      hintStyle: context.title.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: p.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              SizedBox(
                                width: 112,
                                child: PrimaryButton(
                                  key: StatusKeys.find,
                                  label: 'Find',
                                  busy: _looking,
                                  onPressed: _find,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: Motion.short,
                curve: Motion.settle,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.lg,
                    Space.gutter,
                    0,
                  ),
                  child: switch (lookup) {
                    LookupIdle() => const SizedBox(width: double.infinity),
                    LookupEmpty() => const Notice(
                      'Enter a flight number, such as HC 318.',
                      error: true,
                    ),
                    LookupNotFound(:final code) => Notice(
                      'No flight $code today. Check the number on your ticket.',
                      error: true,
                    ),
                    LookupFound(:final flight) => StatusCard(
                      key: ValueKey('found-${flight.id}'),
                      flight: flight,
                      trailing: _FollowButton(
                        following: codes.contains(
                          normaliseFlightCode(flight.code),
                        ),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(trackedProvider.notifier).add(flight.code);
                          setState(() {
                            _lookup = const LookupIdle();
                            _code.clear();
                          });
                        },
                      ),
                    ),
                  },
                ),
              ),
              SectionTitle(
                rows.isEmpty ? 'Following' : 'Following ${tracked.length}',
              ),
              if (rows.isEmpty)
                const EmptyState(
                  title: 'Not following any flights',
                  message:
                      'Find a flight by its number and follow it. Its plane shows here, wherever it is.',
                )
              else
                for (final f in rows)
                  Removable(
                    key: ValueKey('following-${f.id}'),
                    gone: _leaving.containsKey(f.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.md,
                      ),
                      child: StatusCard(
                        flight: f,
                        trailing: RoundIcon(
                          key: Key('unfollow-${f.airline}${f.number}'),
                          icon: Icons.close_rounded,
                          label: 'Stop following ${f.code}',
                          color: p.muted,
                          onTap: () => _unfollow(f),
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

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: Semantics(
        button: true,
        enabled: !following,
        label: following ? 'Already following' : 'Follow this flight',
        excludeSemantics: true,
        child: GestureDetector(
          key: StatusKeys.follow,
          onTap: following ? null : onTap,
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: following ? p.field : p.accent,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              following ? 'Following' : 'Follow',
              style: context.title.copyWith(
                fontSize: 13.5,
                color: following ? p.muted : p.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

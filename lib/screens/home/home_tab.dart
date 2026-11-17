import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/flight.dart';
import '../../models/money.dart';
import '../../models/trip.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../providers/trip_providers.dart';
import '../../services/flight_repository.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sky_scene.dart';
import '../../widgets/ticket.dart';
import '../actions.dart';
import '../auth/auth_screen.dart' show skyHeroTag;
import '../shell/main_shell.dart';
import '../splash/splash_overlay.dart';
import 'search_card.dart';

/// Search: the sky, a greeting, the search form cut into the sky's lower
/// edge, the trip that leaves next, recent searches and popular routes.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _rise(double from, Widget child) {
    final a = CurvedAnimation(
      parent: _enter,
      curve: Interval(from, (from + .5).clamp(0, 1), curve: Motion.enter),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final next = ref.watch(nextTripProvider);
    final recents = ref.watch(recentSearchesProvider);
    final deals = ref.watch(popularRoutesProvider);
    return Material(
      color: p.paper,
      child: Stack(
        children: [
          SkyBackdrop(controller: _scroll),
          ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              bottom: media.padding.bottom + Sizes.tabBarReserve,
            ),
            children: [
              Stack(
                children: [
                  Hero(
                    tag: skyHeroTag,
                    child: SkyHeader(height: Sizes.homeHeader),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      media.padding.top + 14,
                      Space.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rise(
                          0,
                          Row(
                            children: [
                              Avatar(profile: profile, size: 42),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Text(
                                  profile == null
                                      ? 'Welcome'
                                      : 'Welcome, ${profile.firstName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.title.copyWith(
                                    color: p.onSkyMuted,
                                  ),
                                ),
                              ),
                              if (next != null) _NextChip(trip: next),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        _rise(
                          .08,
                          Text(
                            'Where to next?',
                            style: context.display.copyWith(
                              fontSize: 32,
                              color: p.onSky,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.xl),
                        _rise(.16, const SearchCard()),
                      ],
                    ),
                  ),
                ],
              ),
              if (recents.isNotEmpty) _rise(.3, _Recents(recents: recents)),
              _rise(.36, const SectionTitle('Popular routes')),
              _rise(
                .4,
                SizedBox(
                  height: _RouteCard.height,
                  child: deals.when(
                    data: (list) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: Space.md),
                      itemBuilder: (context, i) => _RouteCard(deal: list[i]),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Skeleton(height: _RouteCard.height),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      child: Notice(
                        'Routes could not be loaded. Pull down to try again.',
                        error: true,
                      ),
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

/// Fills the strip a pull-down opens above the sky with the sky's own top
/// colour, so the header never comes away from the top of the screen.
class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key, required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.sky.first;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulled = controller.hasClients && controller.offset < 0
            ? -controller.offset
            : 0.0;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: pulled + 1,
            width: double.infinity,
            child: ColoredBox(color: color),
          ),
        );
      },
    );
  }
}

/// The next trip, small, in the header: where to and how soon.
class _NextChip extends ConsumerWidget {
  const _NextChip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = FlightStatus.of(trip.flight, ref.watch(nowProvider));
    final text = status.phase == FlightPhase.inAir
        ? '${trip.flight.to} ${status.line.toLowerCase()}'
        : '${trip.flight.to} in ${When.span(status.untilDepart)}';
    return Semantics(
      button: true,
      label: 'Next trip, $text',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('home-next-trip'),
        onTap: () => openTrip(context, trip),
        child: StatusChip(text, onSky: true, live: false),
      ),
    );
  }
}

class _Recents extends ConsumerWidget {
  const _Recents({required this.recents});

  final List<SearchQuery> recents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Recent searches',
          action: 'Clear',
          onAction: () => ref.read(recentSearchesProvider.notifier).clear(),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: recents.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final q = recents[i];
              return Container(
                decoration: BoxDecoration(
                  color: p.card,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      key: Key('recent-${q.from}-${q.to}'),
                      borderRadius: BorderRadius.circular(Radii.pill),
                      onTap: () {
                        final today = When.dateOnly(ref.read(clockProvider)());
                        runSearch(
                          context,
                          q.date.isBefore(today)
                              ? q.copyWith(date: today, oneWay: true)
                              : q,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        child: Center(
                          child: Text(
                            '${q.from} to ${q.to} · ${q.date.day} ${When.month(q.date)}',
                            style: context.title.copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Remove ${q.from} to ${q.to} from recent searches',
                      excludeSemantics: true,
                      child: InkResponse(
                        radius: 20,
                        onTap: () =>
                            ref.read(recentSearchesProvider.notifier).remove(q),
                        child: SizedBox(
                          width: 36,
                          height: 44,
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A popular route as a small ticket: the path on top, the lowest fare on
/// the stub. Tapping it runs the search.
class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.deal});

  final RouteDeal deal;

  static const height = 202.0;
  static const _tear = 134.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = deal.flight;
    final world = ref.watch(worldProvider).valueOrNull;
    final draft = ref.watch(searchDraftProvider);
    return Semantics(
      button: true,
      label:
          '${world?.maybeAirport(f.from)?.city ?? f.from} to ${world?.maybeAirport(f.to)?.city ?? f.to}, from ${money(f.priceCents)}',
      excludeSemantics: true,
      child: Pressable(
        key: Key('route-${f.from}-${f.to}'),
        haptic: true,
        onTap: () => runSearch(
          context,
          SearchQuery(
            from: f.from,
            to: f.to,
            date: draft.date,
            adults: draft.adults,
            cabin: draft.cabin,
          ),
        ),
        child: SizedBox(
          width: 268,
          child: Material(
            color: p.card,
            shape: TicketShape(
              notchAt: _tear,
              side: BorderSide(color: p.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: _tear,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.lg,
                      Space.lg,
                      0,
                    ),
                    child: FlightLine(
                      flight: f,
                      times: false,
                      codeSize: 26,
                      arcHeight: 52,
                    ),
                  ),
                ),
                const Perforation(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            world?.airline(f.airline).name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.caption,
                          ),
                        ),
                        Text('from ', style: context.caption),
                        Text(
                          money(f.priceCents),
                          style: context.price.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Goes to the trips tab. Used by empty states on other tabs.
void goToTrips(BuildContext context) => ProviderScope.containerOf(
  context,
  listen: false,
).read(shellTabProvider.notifier).state = ShellTab.trips;

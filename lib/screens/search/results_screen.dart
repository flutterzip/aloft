import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/flight.dart';
import '../../models/when.dart';
import '../../providers/core_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/flight_line.dart';
import '../../widgets/route_arc.dart';
import '../../widgets/segmented.dart';
import '../../widgets/sky_scene.dart';
import '../actions.dart';
import 'fare_strip.dart';
import 'flight_card.dart';

enum FlightSort {
  cheapest('Cheapest'),
  fastest('Fastest'),
  earliest('Earliest');

  const FlightSort(this.label);
  final String label;
}

/// The flights for a search. While they load, a plane flies the route
/// across the header; when they arrive it lands and the flights rise in.
///
/// For a return, picking a flight here opens this page again for the way
/// back ([outbound] is the flight already picked), and picking there goes
/// on to booking.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.query, this.outbound});

  final SearchQuery query;
  final Flight? outbound;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with TickerProviderStateMixin {
  late SearchQuery _query = widget.outbound == null
      ? widget.query
      : widget.query.back;
  late final AnimationController _flight;
  late final AnimationController _reveal;
  FlightSort _sort = FlightSort.cheapest;
  bool _nonStop = false;
  bool _landed = false;
  ProviderSubscription<AsyncValue<List<Flight>>>? _sub;

  bool get _choosingReturn => widget.outbound != null;

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(vsync: this, duration: Motion.flight);
    _reveal = AnimationController(vsync: this, duration: Motion.entrance);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeOff());
  }

  /// Flies the plane until the results for the current query arrive, lets
  /// it finish the lap it is on, then lets the list in.
  void _takeOff() {
    if (!mounted) return;
    _sub?.close();
    setState(() => _landed = false);
    _reveal.value = 0;
    final calm = !Motion.loops(context);
    if (calm) {
      _flight.value = 1;
    } else {
      _flight.repeat();
    }
    _sub = ref.listenManual(searchResultsProvider(searchKey(_query)), (
      _,
      next,
    ) async {
      if (next.isLoading) return;
      if (!calm) {
        await _flight.forward(from: _flight.value);
        if (!mounted) return;
        HapticFeedback.lightImpact();
      }
      setState(() => _landed = true);
      _reveal.forward();
    }, fireImmediately: true);
  }

  void _setDate(DateTime day) {
    if (When.sameDay(day, _query.date)) return;
    HapticFeedback.selectionClick();
    setState(() => _query = _query.copyWith(date: day));
    _takeOff();
  }

  void _pick(Flight flight, Offset origin) {
    HapticFeedback.mediumImpact();
    if (widget.query.roundTrip && !_choosingReturn) {
      tabNavigatorOf(
        context,
      ).push(tabRoute(ResultsScreen(query: widget.query, outbound: flight)));
      return;
    }
    openBooking(
      context,
      query: widget.query,
      flights: [?widget.outbound, flight],
      origin: origin,
    );
  }

  @override
  void dispose() {
    _sub?.close();
    _flight.dispose();
    _reveal.dispose();
    super.dispose();
  }

  List<Flight> _shown(List<Flight> all) {
    final list = [
      for (final f in all)
        if (!_nonStop || f.nonStop) f,
    ];
    switch (_sort) {
      case FlightSort.cheapest:
        list.sort((a, b) => a.priceCents.compareTo(b.priceCents));
      case FlightSort.fastest:
        list.sort((a, b) => a.duration.compareTo(b.duration));
      case FlightSort.earliest:
        list.sort((a, b) => a.depart.compareTo(b.depart));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final key = searchKey(_query);
    final results = ref.watch(searchResultsProvider(key));
    final fares = ref.watch(faresProvider(key)).valueOrNull ?? const {};
    final world = ref.watch(worldProvider).valueOrNull;
    final tone = FlightTone.sky(context);
    final from = world?.maybeAirport(_query.from);
    final to = world?.maybeAirport(_query.to);

    final Widget body;
    if (!_landed) {
      body = ListView(
        key: const ValueKey('loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          Text(
            'Finding flights to ${to?.city ?? _query.to}',
            style: context.caption,
          ),
          const SizedBox(height: Space.md),
          for (var i = 0; i < 3; i++) ...[
            const Skeleton(height: 168),
            const SizedBox(height: Space.md),
          ],
        ],
      );
    } else if (results.hasError) {
      body = Center(
        key: const ValueKey('error'),
        child: EmptyState(
          title: 'Flights could not be loaded',
          message: 'Check your connection and try again.',
          action: 'Try again',
          onAction: () {
            ref.invalidate(searchResultsProvider(key));
            _takeOff();
          },
        ),
      );
    } else {
      final all = results.valueOrNull ?? const <Flight>[];
      final shown = _shown(all);
      if (shown.isEmpty) {
        final filtered = all.isNotEmpty;
        body = Center(
          key: const ValueKey('empty'),
          child: SingleChildScrollView(
            child: EmptyState(
              title: filtered
                  ? 'No non-stop flights on this route'
                  : 'No flights left on ${When.day(_query.date)}',
              message: filtered
                  ? '${from?.city ?? _query.from} to ${to?.city ?? _query.to} is too far to fly in one go. There ${all.length == 1 ? 'is 1 flight' : 'are ${all.length} flights'} with a stop.'
                  : 'Every flight that day has already left. The next day has more.',
              action: filtered
                  ? 'Show flights with a stop'
                  : 'Try the next day',
              onAction: filtered
                  ? () => setState(() => _nonStop = false)
                  : () => _setDate(_query.date.add(const Duration(days: 1))),
            ),
          ),
        );
      } else {
        body = ListView.builder(
          key: ValueKey('list-$key'),
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            media.padding.bottom + Sizes.tabBarReserve,
          ),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final start = (i * .12).clamp(0.0, .6);
            final a = CurvedAnimation(
              parent: _reveal,
              curve: Interval(
                start,
                (start + .4).clamp(0, 1),
                curve: Motion.enter,
              ),
            );
            return FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .18),
                  end: Offset.zero,
                ).animate(a),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: FlightCard(
                    flight: shown[i],
                    best: i == 0 && _sort == FlightSort.cheapest,
                    onSelect: (origin) => _pick(shown[i], origin),
                  ),
                ),
              ),
            );
          },
        );
      }
    }

    return Material(
      color: p.paper,
      child: Column(
        children: [
          SkyHeader(
            height: 186,
            sun: const Alignment(.9, 1.1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, Space.gutter, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: p.onSky,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _choosingReturn
                                ? 'Choose your flight back'
                                : widget.query.roundTrip
                                ? 'Choose your flight out'
                                : 'Choose your flight',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.heading.copyWith(color: p.onSky),
                          ),
                        ),
                        StatusChip(
                          '${_query.adults} · ${_query.cabin.label}',
                          onSky: true,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.gutter - 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _End(code: _query.from, city: from?.city, tone: tone),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 22),
                              child: SizedBox(
                                height: 76,
                                child: _HeaderArc(flight: _flight, tone: tone),
                              ),
                            ),
                          ),
                          _End(
                            code: _query.to,
                            city: to?.city,
                            tone: tone,
                            end: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                ],
              ),
            ),
          ),
          FareStrip(selected: _query.date, fares: fares, onPick: _setDate),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Segmented<FlightSort>(
                    values: FlightSort.values,
                    value: _sort,
                    label: (s) => s.label,
                    onChanged: (s) => setState(() => _sort = s),
                    height: 40,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Semantics(
                  button: true,
                  selected: _nonStop,
                  label: 'Non-stop only',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const Key('filter-nonstop'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _nonStop = !_nonStop);
                    },
                    child: AnimatedContainer(
                      duration: Motion.quick,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _nonStop ? p.ink : p.field,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        'Non-stop',
                        style: context.title.copyWith(
                          fontSize: 13.5,
                          color: _nonStop ? p.paper : p.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(duration: Motion.short, child: body),
          ),
        ],
      ),
    );
  }
}

/// The navigator this page is in, so the way back opens beside it.
NavigatorState tabNavigatorOf(BuildContext context) => Navigator.of(context);

class _End extends StatelessWidget {
  const _End({
    required this.code,
    required this.city,
    required this.tone,
    this.end = false,
  });

  final String code;
  final String? city;
  final FlightTone tone;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(code, style: context.code.copyWith(fontSize: 34, color: tone.ink)),
      const SizedBox(height: 2),
      Text(city ?? '', style: context.caption.copyWith(color: tone.muted)),
    ],
  );
}

class _HeaderArc extends StatelessWidget {
  const _HeaderArc({required this.flight, required this.tone});

  final Animation<double> flight;
  final FlightTone tone;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RouteArc(
      progress: CurvedAnimation(parent: flight, curve: Curves.easeInOutSine),
      line: tone.line,
      flown: tone.plane,
      plane: tone.ink,
      planeSize: 26,
      stroke: 2,
      bow: .6,
      shadow: context.palette.sky.first.withValues(alpha: .35),
    ),
  );
}

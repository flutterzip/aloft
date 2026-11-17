import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aloft/kit/kit.dart';

import '../config/motion.dart';
import '../models/flight.dart';
import '../models/trip.dart';
import '../providers/trip_providers.dart';
import '../widgets/common.dart';
import 'booking/booking_screen.dart';
import 'search/results_screen.dart';
import 'shell/main_shell.dart';
import 'trips/pass_sheet.dart';
import 'trips/trip_detail_screen.dart';

// What a tap does, wherever it happens. Screens call these rather than
// wiring navigation themselves, so a flight or a trip behaves the same
// wherever it is shown.

/// A page inside the current tab, so the glass bar stays.
Route<T> tabRoute<T>(Widget page, {String? name}) => MaterialPageRoute<T>(
  settings: RouteSettings(name: name),
  builder: (_) => page,
);

/// Shows [tab] and opens a page inside it. A tab that has never been
/// opened has no navigator until the frame after it is shown, so the push
/// waits for it.
void _openInTab(
  ProviderContainer container,
  ShellTab tab,
  Route<void> Function() route,
) {
  container.read(shellTabProvider.notifier).state = tab;
  final ready = tabNavigatorKeys[tab]!.currentState;
  if (ready != null) {
    ready.push(route());
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => tabNavigatorKeys[tab]!.currentState?.push(route()),
  );
  WidgetsBinding.instance.scheduleFrame();
}

/// Runs [query]: remembers it and opens the results inside the search tab.
void runSearch(BuildContext context, SearchQuery query) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(searchDraftProvider.notifier).set(query);
  container.read(recentSearchesProvider.notifier).add(query);
  _openInTab(
    container,
    ShellTab.home,
    () => tabRoute(ResultsScreen(query: query)),
  );
}

/// Booking is its own mode: it arrives as ink spreading from where the
/// flight was tapped, over the whole shell.
void openBooking(
  BuildContext context, {
  required SearchQuery query,
  required List<Flight> flights,
  Offset? origin,
}) {
  Navigator.of(context, rootNavigator: true).push(
    ShaderPageRoute<void>(
      effect: ShaderTransition.ink,
      origin: origin,
      duration: Motion.inkRoute,
      builder: (_) => BookingScreen(query: query, flights: flights),
    ),
  );
}

void openTrip(BuildContext context, Trip trip) =>
    openTripIn(ProviderScope.containerOf(context, listen: false), trip);

/// The same, for a caller whose own page is on its way out.
void openTripIn(ProviderContainer container, Trip trip) => _openInTab(
  container,
  ShellTab.trips,
  () => tabRoute(TripDetailScreen(tripId: trip.id)),
);

/// The glass bar's own pane: the boarding pass of the trip that leaves
/// next, or a plain word when there is none.
void openNextPass(BuildContext context) {
  final next = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(nextTripProvider);
  if (next == null) {
    showToast(
      context,
      'No upcoming trip. Book one and its pass lives here.',
      icon: Icons.info_outline_rounded,
    );
    return;
  }
  showPassSheet(context, next.id);
}

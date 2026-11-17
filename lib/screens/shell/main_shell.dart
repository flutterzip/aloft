import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aloft/kit/kit.dart';

import '../../config/app_theme.dart';
import '../../config/motion.dart';
import '../../providers/trip_providers.dart';
import '../actions.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';
import '../splash/splash_overlay.dart';
import '../status/status_tab.dart';
import '../trips/trips_tab.dart';

enum ShellTab {
  home('Search', Icons.travel_explore_rounded),
  trips('Trips', Icons.airplane_ticket_rounded),
  status('Status', Icons.radar_rounded),
  profile('You', Icons.person_rounded);

  const ShellTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

final shellTabProvider = StateProvider<ShellTab>((_) => ShellTab.home);

/// One navigator per tab. Pages pushed from a tab (results, a trip) open
/// inside it, so the glass bar stays and each tab keeps its own history.
final tabNavigatorKeys = {
  for (final t in ShellTab.values)
    t: GlobalKey<NavigatorState>(debugLabel: 'tab-${t.name}'),
};

/// The navigator of the tab on screen. Use it from anywhere, including a
/// sheet that lives on the root navigator, to open a page within the shell.
NavigatorState tabNavigator(BuildContext context) {
  final tab = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(shellTabProvider);
  return tabNavigatorKeys[tab]!.currentState ?? Navigator.of(context);
}

/// Search, Trips, Status and You, under a floating glass tab bar whose
/// separate pane opens the next boarding pass.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  /// Tabs are built the first time they are opened, then kept.
  final _visited = <ShellTab>{};
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  static Widget _page(ShellTab t) => switch (t) {
    ShellTab.home => const HomeTab(),
    ShellTab.trips => const TripsTab(),
    ShellTab.status => const StatusTab(),
    ShellTab.profile => const ProfileTab(),
  };

  Widget _tab(ShellTab t) {
    final key = tabNavigatorKeys[t]!;
    // Android back and the iOS edge swipe pop inside the tab first.
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => key.currentState?.maybePop(),
      child: Navigator(
        key: key,
        // Nested navigators need their own controller for Heroes to fly.
        observers: [HeroController()],
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: (_) => _page(t)),
      ),
    );
  }

  void _select(int index) =>
      ref.read(shellTabProvider.notifier).state = ShellTab.values[index];

  /// Tapping the tab you are on goes back to its first page.
  void _reselect(int index) => tabNavigatorKeys[ShellTab.values[index]]!
      .currentState
      ?.popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tab = ref.watch(shellTabProvider);
    final next = ref.watch(nextTripProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    _visited.add(tab);
    final rise = CurvedAnimation(
      parent: _enter,
      curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
    );
    return Scaffold(
      // Pages handle the keyboard themselves; the bar never rides up on it.
      resizeToAvoidBottomInset: false,
      backgroundColor: p.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: tab.index,
              children: [
                for (final t in ShellTab.values)
                  // Hidden tabs stay mounted. Their Heroes must not join a
                  // flight in another tab, and their skies must not tick.
                  HeroMode(
                    enabled: t == tab,
                    child: TickerMode(
                      enabled: t == tab,
                      child: _visited.contains(t)
                          ? _tab(t)
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottom + 10,
            child: FadeTransition(
              opacity: rise,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .6),
                  end: Offset.zero,
                ).animate(rise),
                child: LiquidGlassTabBar(
                  currentIndex: tab.index,
                  onChanged: _select,
                  onReselected: _reselect,
                  settings: LiquidGlassSettings(tint: p.glassTint),
                  items: [
                    for (final t in ShellTab.values)
                      GlassTabItem(icon: t.icon, label: t.label),
                  ],
                  action: Icons.qr_code_2_rounded,
                  actionLabel: next == null
                      ? 'Boarding pass, no upcoming trip'
                      : 'Boarding pass for your next trip',
                  onAction: () => openNextPass(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

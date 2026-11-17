import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../providers/account_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/reset.dart';
import '../../providers/session_providers.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sky_scene.dart';
import '../actions.dart';
import '../auth/auth_screen.dart';
import '../home/home_tab.dart' show SkyBackdrop;
import '../shell/main_shell.dart';
import 'avatar_sheet.dart';
import 'cards_screen.dart';
import 'edit_profile_sheet.dart';
import 'profile_parts.dart';
import 'records.dart';
import 'travellers_screen.dart';

abstract final class ProfileKeys {
  static const edit = Key('profile-edit');
  static const travellers = Key('profile-travellers');
  static const cards = Key('profile-cards');
  static const reset = Key('profile-reset');
  static const signOut = Key('profile-sign-out');
}

/// You: photo and details on the sky, what you have flown, travellers,
/// cards, appearance, and the way out.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Leaves the shell for [page]. The shell stays alive under the
  /// cross-fade and [then] runs once it has gone, so nothing blanks
  /// mid-flight.
  static Future<void> _leave(
    BuildContext context,
    Widget page,
    Future<void> Function(ProviderContainer) then,
  ) async {
    // The page's own ref is disposed with it: act through the container.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement(handOffRoute(page));
    await Future<void>.delayed(
      Motion.handOff + const Duration(milliseconds: 50),
    );
    await then(container);
    container.read(shellTabProvider.notifier).state = ShellTab.home;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final stats = ref.watch(travelStatsProvider);
    final travellers = ref.watch(travellersProvider).valueOrNull?.length ?? 0;
    final cards = ref.watch(cardsProvider).valueOrNull?.length ?? 0;
    final hasPhoto =
        (profile?.avatar.isNotEmpty ?? false) ||
        ref.watch(pendingAvatarProvider) != null;

    void push(Widget page) => tabNavigator(context).push(tabRoute(page));

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
                  const SkyHeader(height: 172, sun: Alignment(-.7, 1)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      media.padding.top + Space.lg,
                      Space.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Change profile photo',
                              child: GestureDetector(
                                key: AvatarKeys.avatar,
                                onTap: () => showAvatarSheet(
                                  context,
                                  hasPhoto: hasPhoto,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Avatar(profile: profile, size: 72),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: p.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: p.sky[1],
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.photo_camera_outlined,
                                          size: 14,
                                          color: p.onAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile?.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.display.copyWith(
                                      fontSize: 24,
                                      color: p.onSky,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    profile?.email ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.caption.copyWith(
                                      color: p.onSkyMuted,
                                    ),
                                  ),
                                  if (profile?.phone.isNotEmpty ?? false)
                                    Text(
                                      profile!.phone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.caption.copyWith(
                                        color: p.onSkyMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            RoundIcon(
                              key: ProfileKeys.edit,
                              icon: Icons.edit_outlined,
                              label: 'Edit your details',
                              color: p.onSky,
                              onTap: profile == null
                                  ? null
                                  : () =>
                                        showEditProfileSheet(context, profile),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.xl),
                        TravelStatsCard(
                          stats: stats,
                          member: profile?.memberNumber ?? '',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.xl,
                  Space.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: ProfileKeys.travellers,
                          icon: Icons.group_outlined,
                          label: 'Travellers',
                          value: travellers == 0 ? 'None yet' : '$travellers',
                          onTap: () => push(const TravellersScreen()),
                        ),
                        SettingsRow(
                          key: ProfileKeys.cards,
                          icon: Icons.credit_card_rounded,
                          label: 'Payment methods',
                          value: cards == 0 ? 'None yet' : '$cards',
                          onTap: () => push(const CardsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    Text(
                      'APPEARANCE',
                      style: context.label.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: Space.md),
                    const AppearancePicker(),
                    const SizedBox(height: Space.xl),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: ProfileKeys.reset,
                          icon: Icons.restart_alt_rounded,
                          label: 'Reset demo data',
                          onTap: () async {
                            final yes = await confirmRemove(
                              context,
                              title: 'Reset demo data?',
                              message:
                                  'Your trips, followed flights, travellers, cards and details go back to how they started, and you are signed out.',
                              action: 'Reset everything',
                            );
                            if (!yes || !context.mounted) return;
                            await _leave(
                              context,
                              const AuthScreen(),
                              resetDemoData,
                            );
                          },
                        ),
                        SettingsRow(
                          key: ProfileKeys.signOut,
                          icon: Icons.logout_rounded,
                          label: 'Sign out',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _leave(
                              context,
                              const AuthScreen(),
                              (c) => c.read(sessionProvider.notifier).signOut(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/flight.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';
import '../actions.dart';
import 'boarding_pass.dart';
import 'check_in.dart';

/// The boarding pass, one tap from anywhere: opened by the glass bar's own
/// pane. Checks in from here when check-in is open.
Future<void> showPassSheet(BuildContext context, String tripId) =>
    showAppSheet<void>(
      context,
      title: 'Your boarding pass',
      builder: (_) => _PassSheet(tripId: tripId),
    );

class _PassSheet extends ConsumerStatefulWidget {
  const _PassSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_PassSheet> createState() => _PassSheetState();
}

class _PassSheetState extends ConsumerState<_PassSheet> {
  final _pass = GlobalKey<FlipPassState>();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId));
    if (trip == null) return const SizedBox(height: 120);
    final now = ref.watch(nowProvider);
    final status = FlightStatus.of(trip.flight, now);
    final canCheckIn = trip.canCheckIn(now);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xs,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusChip(status.headline, live: status.live || status.delayed),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  status.line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          FlipPass(key: _pass, trip: trip),
          const SizedBox(height: Space.lg),
          if (canCheckIn)
            PrimaryButton(
              key: const Key('pass-check-in'),
              label: 'Check in now',
              icon: Icons.how_to_reg_outlined,
              busy: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                await checkIn(context, ref, trip);
                if (!mounted) return;
                setState(() => _busy = false);
                _pass.currentState?.flip(toBack: true);
              },
            )
          else
            PrimaryButton(
              key: const Key('pass-open-trip'),
              quiet: true,
              label: 'Trip details',
              onPressed: () {
                Navigator.of(context).pop();
                openTrip(context, trip);
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_timing.dart';
import '../../models/trip.dart';
import '../../providers/trip_providers.dart';
import '../../widgets/common.dart';

/// Checks [trip] in, waiting as a real request would, and says so. Shared
/// by the pass sheet, the trips tab and a trip's page.
Future<void> checkIn(BuildContext context, WidgetRef ref, Trip trip) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await AppTiming.atLeast(
    AppTiming.checkIn,
    ref.read(tripsProvider.notifier).checkIn(trip),
  );
  HapticFeedback.mediumImpact();
  if (messenger != null && context.mounted) {
    showToast(context, 'Checked in. Seat ${trip.seats.join(', ')}');
  }
}

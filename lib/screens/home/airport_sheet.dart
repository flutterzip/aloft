import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/airport.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';

/// Picks an airport. [other] is the far end of the route, which cannot be
/// chosen and says why.
Future<Airport?> showAirportSheet(
  BuildContext context, {
  required String title,
  required String current,
  required String other,
}) => showAppSheet<Airport>(
  context,
  title: title,
  builder: (_) => _AirportSheet(current: current, other: other),
);

class _AirportSheet extends ConsumerStatefulWidget {
  const _AirportSheet({required this.current, required this.other});

  final String current;
  final String other;

  @override
  ConsumerState<_AirportSheet> createState() => _AirportSheetState();
}

class _AirportSheetState extends ConsumerState<_AirportSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final world = ref.watch(worldProvider).valueOrNull;
    final found = [
      for (final a in world?.airports ?? const <Airport>[])
        if (a.matches(_query)) a,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .74,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.md,
            ),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: p.muted),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: TextField(
                      key: const Key('airport-search'),
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: context.title,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'City, airport or code',
                        hintStyle: context.title.copyWith(
                          color: p.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: found.isEmpty
                ? EmptyState(
                    title: 'No airport matches',
                    message:
                        'Nothing matches "${_query.trim()}". Try a city or a three-letter code.',
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    itemCount: found.length,
                    itemBuilder: (context, i) {
                      final a = found[i];
                      final taken = a.code == widget.other;
                      final chosen = a.code == widget.current;
                      return Semantics(
                        button: true,
                        enabled: !taken,
                        label:
                            '${a.city}, ${a.name}, ${a.code}${taken ? ', the other end of this trip' : ''}',
                        excludeSemantics: true,
                        child: InkWell(
                          key: Key('airport-${a.code}'),
                          onTap: taken
                              ? null
                              : () => Navigator.of(context).pop(a),
                          child: Opacity(
                            opacity: taken ? .45 : 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.gutter,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: chosen ? p.accentWash : p.field,
                                      borderRadius: BorderRadius.circular(
                                        Radii.sm,
                                      ),
                                    ),
                                    child: Text(
                                      a.code,
                                      style: context.title.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: chosen ? p.accent : p.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Space.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.city,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.title,
                                        ),
                                        Text(
                                          taken
                                              ? 'The other end of this trip'
                                              : '${a.name}, ${a.country}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (chosen)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: p.accent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

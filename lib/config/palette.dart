import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Every colour in the app is defined in this file.
//
// To re-skin Aloft, edit [Palette.light] and [Palette.dark] below. Each
// screen, sheet, button, the sky behind the headers, the logo, the splash,
// the boarding pass, the seat map and the glass tab bar read their colours
// from here through `context.palette`; nothing else in lib/ hard-codes a UI
// colour (a test enforces it).
//
// The one thing deliberately not here: the Apple and Google sign-in buttons
// (lib/widgets/social_buttons.dart), whose colours are fixed by their brand
// guidelines.
//
// The system, and why these colours:
//  * Stratosphere, a deep petrol blue-green. It is the colour of the sky
//    above the weather, where the app's name lives. It carries the headers,
//    the splash and the boarding pass.
//  * International orange, the aerospace signal colour (flight recorders,
//    wind socks, test aircraft). It is the single accent: the sun in the
//    logo, the primary button, the plane on a route.
//  * Cloud, a warm paper white, and a warm ink. Paper is never pure white
//    and ink is never pure black; both lean a little towards the petrol.
// ---------------------------------------------------------------------------

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.line,
    required this.field,
    required this.accent,
    required this.onAccent,
    required this.accentWash,
    required this.error,
    required this.sky,
    required this.onSky,
    required this.onSkyMuted,
    required this.cloud,
    required this.sun,
    required this.pass,
    required this.onPass,
    required this.passLine,
    required this.seatTaken,
    required this.shadow,
    required this.glassTint,
    required this.scrim,
    required this.onIsland,
  });

  /// The page ground.
  final Color paper;

  /// Raised surfaces: cards, sheets, tickets.
  final Color card;

  /// Primary type and icons.
  final Color ink;

  /// Body copy.
  final Color inkSoft;

  /// Captions, hints, inactive icons.
  final Color muted;

  /// Hairlines, dividers, perforations.
  final Color line;

  /// The fill of a text field and of a quiet chip.
  final Color field;

  /// The one accent: the primary button, the plane on a route, a live state.
  final Color accent;

  /// Type and icons on top of [accent].
  final Color onAccent;

  /// A pale tint of the accent for selected chips and notices.
  final Color accentWash;

  /// Errors stay in the accent's family, a deeper neighbour of it.
  final Color error;

  /// The sky behind the splash and every header, from the top down.
  final List<Color> sky;

  /// Type and icons on the sky.
  final Color onSky;
  final Color onSkyMuted;

  /// The cloud banks drawn on the sky, and the cloud inside the logo.
  final Color cloud;

  /// The sun in the logo and its glow on the sky.
  final Color sun;

  /// The boarding pass: its ground, its type and its fine line work.
  final Color pass;
  final Color onPass;
  final Color passLine;

  /// A seat somebody else has.
  final Color seatTaken;

  /// Shadows under cards and the plane.
  final Color shadow;

  /// The tint of the glass tab bar.
  final Color glassTint;

  /// The dim behind a sheet.
  final Color scrim;

  /// Type on the black live-flight pill.
  final Color onIsland;

  static const light = Palette(
    paper: Color(0xFFF4F1EA),
    card: Color(0xFFFCFAF5),
    ink: Color(0xFF12222B),
    inkSoft: Color(0xFF3F4E56),
    muted: Color(0xFF7C888B),
    line: Color(0xFFE2DED4),
    field: Color(0xFFEBE7DE),
    accent: Color(0xFFF2501A),
    onAccent: Color(0xFFFFF8F1),
    accentWash: Color(0xFFFBE4D8),
    error: Color(0xFFC0362C),
    sky: [Color(0xFF081A22), Color(0xFF0E313D), Color(0xFF1B5665)],
    onSky: Color(0xFFF4F1EA),
    onSkyMuted: Color(0xFFA3BEC3),
    cloud: Color(0xFFF4F1EA),
    sun: Color(0xFFFF6A2B),
    pass: Color(0xFF0E2A33),
    onPass: Color(0xFFF6F1E6),
    passLine: Color(0xFFF2E3C8),
    seatTaken: Color(0xFFD9D4C8),
    shadow: Color(0x33102028),
    glassTint: Color(0x8A0E242C),
    scrim: Color(0x66081A22),
    onIsland: Color(0xFFF4F1EA),
  );

  static const dark = Palette(
    paper: Color(0xFF0A151A),
    card: Color(0xFF112027),
    ink: Color(0xFFEEF1EC),
    inkSoft: Color(0xFFC3CDCD),
    muted: Color(0xFF7F8F90),
    line: Color(0xFF1F3138),
    field: Color(0xFF16272E),
    accent: Color(0xFFFF6A33),
    onAccent: Color(0xFFFFF8F1),
    accentWash: Color(0xFF3A1E12),
    error: Color(0xFFF0796B),
    sky: [Color(0xFF040C10), Color(0xFF0A2630), Color(0xFF14475A)],
    onSky: Color(0xFFF4F1EA),
    onSkyMuted: Color(0xFF94B0B6),
    cloud: Color(0xFFD9E2E0),
    sun: Color(0xFFFF7A3D),
    pass: Color(0xFF08181E),
    onPass: Color(0xFFF6F1E6),
    passLine: Color(0xFFF2E3C8),
    seatTaken: Color(0xFF26373E),
    shadow: Color(0x66000000),
    glassTint: Color(0x8A050D11),
    scrim: Color(0x99000000),
    onIsland: Color(0xFFF4F1EA),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> ll(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) l(a[i], b[i]),
    ];
    return Palette(
      paper: l(paper, other.paper),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      field: l(field, other.field),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentWash: l(accentWash, other.accentWash),
      error: l(error, other.error),
      sky: ll(sky, other.sky),
      onSky: l(onSky, other.onSky),
      onSkyMuted: l(onSkyMuted, other.onSkyMuted),
      cloud: l(cloud, other.cloud),
      sun: l(sun, other.sun),
      pass: l(pass, other.pass),
      onPass: l(onPass, other.onPass),
      passLine: l(passLine, other.passLine),
      seatTaken: l(seatTaken, other.seatTaken),
      shadow: l(shadow, other.shadow),
      glassTint: l(glassTint, other.glassTint),
      scrim: l(scrim, other.scrim),
      onIsland: l(onIsland, other.onIsland),
    );
  }
}

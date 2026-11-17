import 'package:flutter/widgets.dart';

/// How things move. How long the app *waits* is a different question and
/// lives in `AppTiming`.
abstract final class Motion {
  static const quick = Duration(milliseconds: 180);
  static const short = Duration(milliseconds: 250);
  static const medium = Duration(milliseconds: 400);
  static const long = Duration(milliseconds: 600);

  /// A screen's sections rising in, from one controller sliced by intervals.
  static const entrance = Duration(milliseconds: 900);

  /// Sign in hands over to the shell, and sign out hands back.
  static const handOff = Duration(milliseconds: 700);

  /// A removed row blowing away, and the gap it leaves closing.
  static const dust = Duration(milliseconds: 900);

  /// Booking arriving through spreading ink.
  static const inkRoute = Duration(milliseconds: 1000);

  /// The plane flying a route arc once.
  static const flight = Duration(milliseconds: 1500);

  /// A boarding pass turning over.
  static const flip = Duration(milliseconds: 700);

  /// A boarding pass feeding out of the printer.
  static const print = Duration(milliseconds: 1400);

  /// How long the sky takes to drift once across. Ambient, very slow.
  static const skyLoop = Duration(seconds: 40);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const settle = Curves.easeOutQuart;

  /// Ambient loops (the sky's clouds, the boarding loader) run only when
  /// this is true. Tests switch it off so `pumpAndSettle` can settle.
  static bool ambient = true;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static bool loops(BuildContext context) => ambient && !reduced(context);
}

/// Dates and durations as the app writes them. No locale package: the
/// template is English, and these are the only formats it uses.
abstract final class When {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String weekday(DateTime d) => _days[d.weekday - 1];
  static String month(DateTime d) => _months[d.month - 1];

  /// "6:05 AM".
  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "Fri, 4 Sep".
  static String day(DateTime d) => '${weekday(d)}, ${d.day} ${month(d)}';

  /// "4 Sep 2026".
  static String date(DateTime d) => '${d.day} ${month(d)} ${d.year}';

  /// "6h 45m", "45m", "2d 4h".
  static String span(Duration d) {
    final m = d.inMinutes.abs();
    if (m >= 48 * 60) return '${m ~/ 1440}d ${(m % 1440) ~/ 60}h';
    if (m >= 60) return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "2026-09-04", for stored searches.
  static String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A small stable hash (FNV-1a), so generated schedules, gates and taken
/// seats are the same every time for the same flight, on every device.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

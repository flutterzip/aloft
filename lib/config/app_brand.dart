/// The product name and the lines that travel with it live here, and only
/// here. Seed JSON refers to the name as `{app}`, substituted at load.
abstract final class AppBrand {
  static const name = 'Aloft';
  static const tagline = 'The window seat, every time';
  static const currencySymbol = '\$';

  /// The prefix of a booking reference's ticket number.
  static const ticketPrefix = 'AL';
}

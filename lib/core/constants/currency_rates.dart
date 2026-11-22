/// Default USD -> LYD reference rate, used only until the admin-managed rate
/// (GET /api/exchange-rates/lyd) has loaded. Not a provider settlement rate.
const double usdToLydRate = 6.4;

/// The USD -> LYD rate in use. Set from the admin setting at startup (and
/// after an admin saves a new value); every conversion reads it from here.
abstract final class LydRate {
  static double _unitsPerUsd = usdToLydRate;

  static double get unitsPerUsd => _unitsPerUsd;

  /// Ignores invalid values so a bad response never breaks prices.
  static void set(double value) {
    if (value.isFinite && value > 0) _unitsPerUsd = value;
  }
}

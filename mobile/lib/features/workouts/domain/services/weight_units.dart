import '../entities/workout_enums.dart';

/// The single place kg/lb conversion happens.
///
/// Weights are stored canonically in kg (rounded to 2 decimals), alongside
/// the value and unit exactly as the user typed them, so the UI can show
/// "135 lb" instead of a round-tripped "134.99 lb".
abstract final class WeightUnits {
  /// Exact international avoirdupois pound.
  static const double kgPerLb = 0.45359237;

  /// Converts [value] in [unit] to canonical kg, rounded to 2 decimals.
  static double toKg(double value, WeightUnit unit) => round2(
        unit == WeightUnit.kg ? value : value * kgPerLb,
      );

  /// Converts canonical [kg] to [unit] for display, rounded to 2 decimals.
  static double fromKg(double kg, WeightUnit unit) => round2(
        unit == WeightUnit.kg ? kg : kg / kgPerLb,
      );

  /// Value to show for a weight that was entered as [entered] [enteredUnit]
  /// (canonically [kg]) when the exercise is displayed in [displayUnit].
  /// Returns the typed value untouched when the units match.
  static double display({
    required double entered,
    required WeightUnit enteredUnit,
    required double kg,
    required WeightUnit displayUnit,
  }) =>
      enteredUnit == displayUnit ? entered : fromKg(kg, displayUnit);

  static double round2(double value) => (value * 100).roundToDouble() / 100;

  /// "60", "62.5", "61.23" — no trailing zeros.
  static String format(double value) {
    final fixed = round2(value).toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

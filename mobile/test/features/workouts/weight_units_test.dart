import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/workouts/domain/entities/logged_set.dart';
import 'package:grit/features/workouts/domain/entities/workout_enums.dart';
import 'package:grit/features/workouts/domain/services/weight_units.dart';

void main() {
  group('WeightUnits.toKg', () {
    test('kg is unchanged', () {
      expect(WeightUnits.toKg(60, WeightUnit.kg), 60);
      expect(WeightUnits.toKg(62.5, WeightUnit.kg), 62.5);
    });

    test('lb uses 0.45359237 and rounds to 2 decimals', () {
      expect(WeightUnits.toKg(1, WeightUnit.lb), 0.45);
      expect(WeightUnits.toKg(135, WeightUnit.lb), 61.23); // 61.2350...
      expect(WeightUnits.toKg(225, WeightUnit.lb), 102.06); // 102.0582...
      expect(WeightUnits.toKg(45, WeightUnit.lb), 20.41); // 20.4117...
    });
  });

  group('WeightUnits.fromKg', () {
    test('converts kg to lb rounded to 2 decimals', () {
      expect(WeightUnits.fromKg(100, WeightUnit.lb), 220.46);
      expect(WeightUnits.fromKg(20, WeightUnit.kg), 20);
    });
  });

  group('round trip', () {
    test('135 lb stored canonically still displays as 135 lb', () {
      const set = LoggedSet(
        id: 's',
        enteredWeight: 135,
        enteredUnit: WeightUnit.lb,
      );
      expect(set.loadKg, 61.23);
      // Naive round trip through kg drifts…
      expect(WeightUnits.fromKg(set.loadKg!, WeightUnit.lb), 134.99);
      // …but display uses the typed value when units match.
      expect(
        WeightUnits.display(
          entered: set.enteredWeight!,
          enteredUnit: set.enteredUnit!,
          kg: set.loadKg!,
          displayUnit: WeightUnit.lb,
        ),
        135,
      );
    });

    test('display converts when the exercise unit differs', () {
      expect(
        WeightUnits.display(
          entered: 135,
          enteredUnit: WeightUnit.lb,
          kg: 61.23,
          displayUnit: WeightUnit.kg,
        ),
        61.23,
      );
    });

    test('every whole kg value survives kg → lb → kg within 0.01', () {
      for (var kg = 1; kg <= 300; kg++) {
        final lb = WeightUnits.fromKg(kg.toDouble(), WeightUnit.lb);
        expect(
          (WeightUnits.toKg(lb, WeightUnit.lb) - kg).abs(),
          lessThanOrEqualTo(0.01),
        );
      }
    });
  });

  test('format drops trailing zeros', () {
    expect(WeightUnits.format(60), '60');
    expect(WeightUnits.format(62.5), '62.5');
    expect(WeightUnits.format(61.23), '61.23');
    expect(WeightUnits.format(100.10), '100.1');
    expect(WeightUnits.format(0), '0');
  });
}

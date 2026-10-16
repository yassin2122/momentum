import '../services/weight_units.dart';
import 'workout_enums.dart';

/// One set inside an in-progress workout.
///
/// Position is the set's index in [LoggedExercise.sets] — there is no stored
/// position field, so removing a set can never leave a gap.
///
/// The load is kept exactly as typed ([enteredWeight] + [enteredUnit]);
/// which kg column it maps to (weight, added or assist) depends on the
/// exercise's tracking type — see [loadKg].
final class LoggedSet {
  const LoggedSet({
    required this.id,
    this.setType = SetType.working,
    this.completed = false,
    this.reps,
    this.enteredWeight,
    this.enteredUnit,
    this.durationS,
    this.rpe,
  });

  final String id;
  final SetType setType;
  final bool completed;
  final int? reps;
  final double? enteredWeight;
  final WeightUnit? enteredUnit;
  final int? durationS;
  final double? rpe;

  /// Canonical kg of the load input, or null when nothing was entered.
  double? get loadKg => enteredWeight == null
      ? null
      : WeightUnits.toKg(enteredWeight!, enteredUnit ?? WeightUnit.kg);

  /// True when no value has been typed into this set.
  bool get isEmpty =>
      reps == null && enteredWeight == null && durationS == null;

  LoggedSet copyWith({
    SetType? setType,
    bool? completed,
    int? Function()? reps,
    double? Function()? enteredWeight,
    WeightUnit? Function()? enteredUnit,
    int? Function()? durationS,
    double? Function()? rpe,
  }) =>
      LoggedSet(
        id: id,
        setType: setType ?? this.setType,
        completed: completed ?? this.completed,
        reps: reps != null ? reps() : this.reps,
        enteredWeight:
            enteredWeight != null ? enteredWeight() : this.enteredWeight,
        enteredUnit: enteredUnit != null ? enteredUnit() : this.enteredUnit,
        durationS: durationS != null ? durationS() : this.durationS,
        rpe: rpe != null ? rpe() : this.rpe,
      );

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
        id: json['id'] as String,
        setType: SetType.fromDb(json['set_type'] as String?),
        completed: json['completed'] as bool? ?? false,
        reps: json['reps'] as int?,
        enteredWeight: (json['entered_weight'] as num?)?.toDouble(),
        enteredUnit: json['entered_unit'] == null
            ? null
            : WeightUnit.fromDb(json['entered_unit'] as String),
        durationS: json['duration_s'] as int?,
        rpe: (json['rpe'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'set_type': setType.dbValue,
        'completed': completed,
        'reps': reps,
        'entered_weight': enteredWeight,
        'entered_unit': enteredUnit?.dbValue,
        'duration_s': durationS,
        'rpe': rpe,
      };
}

/// A set from the last completed session of an exercise, used for the
/// "Last: 60 kg × 8" hint and to pre-fill new sets.
final class PreviousSet {
  const PreviousSet({
    required this.setType,
    this.reps,
    this.loadKg,
    this.enteredWeight,
    this.enteredUnit,
    this.durationS,
  });

  final SetType setType;
  final int? reps;

  /// Canonical kg of whichever load column applied (weight/added/assist).
  final double? loadKg;
  final double? enteredWeight;
  final WeightUnit? enteredUnit;
  final int? durationS;

  /// Builds from a `get_last_exercise_performance` row.
  factory PreviousSet.fromJson(Map<String, dynamic> json) {
    double? n(String key) => (json[key] as num?)?.toDouble();
    return PreviousSet(
      setType: SetType.fromDb(json['set_type'] as String?),
      reps: json['reps'] as int?,
      loadKg: n('weight_kg') ?? n('added_kg') ?? n('assist_kg') ??
          n('load_kg'),
      enteredWeight: n('entered_weight'),
      enteredUnit: json['entered_unit'] == null
          ? null
          : WeightUnit.fromDb(json['entered_unit'] as String),
      durationS: json['duration_s'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'set_type': setType.dbValue,
        'reps': reps,
        'load_kg': loadKg,
        'entered_weight': enteredWeight,
        'entered_unit': enteredUnit?.dbValue,
        'duration_s': durationS,
      };

  /// Load expressed in [unit], preferring the exact typed value.
  double? loadIn(WeightUnit unit) {
    if (enteredWeight != null && enteredUnit == unit) return enteredWeight;
    return loadKg == null ? null : WeightUnits.fromKg(loadKg!, unit);
  }
}

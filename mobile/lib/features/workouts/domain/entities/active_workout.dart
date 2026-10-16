import 'logged_set.dart';
import 'trackable_exercise.dart';
import 'workout_enums.dart';

/// One exercise inside an in-progress workout (`workout_log_exercises`).
final class LoggedExercise {
  const LoggedExercise({
    required this.id,
    required this.exercise,
    required this.unit,
    required this.sets,
    this.notes,
    this.replacedFromExerciseId,
    this.addedDuringWorkout = false,
    this.previousSets = const [],
    this.personalBests = const {},
    this.historyLoaded = false,
  });

  final String id;
  final TrackableExercise exercise;

  /// Display/input unit for this exercise only (the per-exercise toggle).
  final WeightUnit unit;
  final List<LoggedSet> sets;
  final String? notes;
  final String? replacedFromExerciseId;

  /// Added mid-workout (picked or newly created). If the workout came from
  /// a template, these join the template when the workout is finished.
  final bool addedDuringWorkout;

  /// Sets from the last completed session of this exercise.
  final List<PreviousSet> previousSets;

  /// Current all-time bests before this workout, used by the PR summary.
  final Map<PrMetric, double> personalBests;
  final bool historyLoaded;

  LoggedExercise copyWith({
    TrackableExercise? exercise,
    WeightUnit? unit,
    List<LoggedSet>? sets,
    String? Function()? notes,
    String? Function()? replacedFromExerciseId,
    bool? addedDuringWorkout,
    List<PreviousSet>? previousSets,
    Map<PrMetric, double>? personalBests,
    bool? historyLoaded,
  }) =>
      LoggedExercise(
        id: id,
        exercise: exercise ?? this.exercise,
        unit: unit ?? this.unit,
        sets: sets ?? this.sets,
        notes: notes != null ? notes() : this.notes,
        replacedFromExerciseId: replacedFromExerciseId != null
            ? replacedFromExerciseId()
            : this.replacedFromExerciseId,
        addedDuringWorkout: addedDuringWorkout ?? this.addedDuringWorkout,
        previousSets: previousSets ?? this.previousSets,
        personalBests: personalBests ?? this.personalBests,
        historyLoaded: historyLoaded ?? this.historyLoaded,
      );

  factory LoggedExercise.fromJson(Map<String, dynamic> json) => LoggedExercise(
        id: json['id'] as String,
        exercise: TrackableExercise.fromJson(
          Map<String, dynamic>.from(json['exercise'] as Map),
        ),
        unit: WeightUnit.fromDb(json['unit'] as String?),
        sets: [
          for (final s in json['sets'] as List)
            LoggedSet.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        notes: json['notes'] as String?,
        replacedFromExerciseId: json['replaced_from_exercise_id'] as String?,
        addedDuringWorkout: json['added_during_workout'] as bool? ?? false,
        previousSets: [
          for (final s in (json['previous_sets'] as List?) ?? const [])
            PreviousSet.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        personalBests: {
          for (final e in ((json['personal_bests'] as Map?) ?? const {})
              .entries)
            if (PrMetric.fromDb(e.key as String) != null)
              PrMetric.fromDb(e.key as String)!: (e.value as num).toDouble(),
        },
        historyLoaded: json['history_loaded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise': exercise.toJson(),
        'unit': unit.dbValue,
        'sets': [for (final s in sets) s.toJson()],
        'notes': notes,
        'replaced_from_exercise_id': replacedFromExerciseId,
        'added_during_workout': addedDuringWorkout,
        'previous_sets': [for (final s in previousSets) s.toJson()],
        'personal_bests': {
          for (final e in personalBests.entries) e.key.dbValue: e.value,
        },
        'history_loaded': historyLoaded,
      };
}

/// The in-progress workout. Lives on the device (saved on every change)
/// until it is finished — then it goes to Supabase via `finish_workout` —
/// or discarded, in which case it never leaves the device.
final class ActiveWorkout {
  const ActiveWorkout({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.exercises,
    this.templateId,
    this.templateName,
    this.bodyweightKg,
  });

  /// Client-generated; becomes `workout_logs.id`, which makes the
  /// finish call idempotent for offline retries.
  final String id;
  final String userId;
  final DateTime startedAt;
  final List<LoggedExercise> exercises;
  final String? templateId;
  final String? templateName;

  /// Latest known bodyweight, for the on-device summary. The server takes
  /// its own snapshot on finish.
  final double? bodyweightKg;

  String get title => templateName ?? 'Workout';

  ActiveWorkout copyWith({
    List<LoggedExercise>? exercises,
    double? Function()? bodyweightKg,
  }) =>
      ActiveWorkout(
        id: id,
        userId: userId,
        startedAt: startedAt,
        exercises: exercises ?? this.exercises,
        templateId: templateId,
        templateName: templateName,
        bodyweightKg: bodyweightKg != null ? bodyweightKg() : this.bodyweightKg,
      );

  factory ActiveWorkout.fromJson(Map<String, dynamic> json) => ActiveWorkout(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        exercises: [
          for (final e in json['exercises'] as List)
            LoggedExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        templateId: json['template_id'] as String?,
        templateName: json['template_name'] as String?,
        bodyweightKg: (json['bodyweight_kg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'exercises': [for (final e in exercises) e.toJson()],
        'template_id': templateId,
        'template_name': templateName,
        'bodyweight_kg': bodyweightKg,
      };
}

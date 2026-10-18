/// The dashboard's discipline score, as returned by `get_discipline_score`.
///
/// score = 100 × (0.5 × activeRatio + 0.5 × workoutRatio) over the last
/// [windowDays] days; with no templates (no plan) it is activeRatio alone.
final class DisciplineScore {
  const DisciplineScore({
    required this.score,
    required this.windowDays,
    required this.activeDays,
    required this.completedWorkouts,
    required this.templates,
    this.plannedWorkouts,
    this.workoutRatio,
  });

  /// 0–100.
  final int score;
  final int windowDays;
  final int activeDays;
  final int completedWorkouts;
  final int templates;

  /// Null when the user has no templates yet.
  final double? plannedWorkouts;
  final double? workoutRatio;

  bool get hasPlan => plannedWorkouts != null;

  factory DisciplineScore.fromJson(Map<String, dynamic> json) =>
      DisciplineScore(
        score: ((json['score'] as num?)?.toInt() ?? 0).clamp(0, 100),
        windowDays: (json['window_days'] as num?)?.toInt() ?? 30,
        activeDays: (json['active_days'] as num?)?.toInt() ?? 0,
        completedWorkouts: (json['completed_workouts'] as num?)?.toInt() ?? 0,
        templates: (json['templates'] as num?)?.toInt() ?? 0,
        plannedWorkouts: (json['planned_workouts'] as num?)?.toDouble(),
        workoutRatio: (json['workout_ratio'] as num?)?.toDouble(),
      );
}

/// A finished workout that hasn't reached Supabase yet (offline, or the
/// request failed). Resent as-is; `finish_workout` is idempotent on the id.
final class PendingWorkout {
  const PendingWorkout({
    required this.workoutId,
    required this.title,
    required this.payload,
    this.lastError,
  });

  final String workoutId;
  final String title;
  final Map<String, dynamic> payload;
  final String? lastError;

  PendingWorkout withError(String? error) => PendingWorkout(
        workoutId: workoutId,
        title: title,
        payload: payload,
        lastError: error,
      );

  factory PendingWorkout.fromJson(Map<String, dynamic> json) => PendingWorkout(
        workoutId: json['workout_id'] as String,
        title: json['title'] as String? ?? 'Workout',
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        lastError: json['last_error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        'title': title,
        'payload': payload,
        'last_error': lastError,
      };
}

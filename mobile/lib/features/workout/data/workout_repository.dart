import '../../../main.dart' show supabase;
import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';

/// Real Supabase-backed replacement for the mock dashboard providers.
/// PR and streak tables are read-only here — they're written server-side
/// by triggers (`check_and_update_personal_record`, `bump_streak`) fired
/// off `workout_log_sets` inserts and `workout_logs.completed_at` updates.
class WorkoutRepository {
  const WorkoutRepository();

  Future<List<Exercise>> searchExercises(String query) async {
    final rows = await supabase
        .from('exercises')
        .select()
        .ilike('name', '%$query%')
        .limit(30);
    return rows.map((r) => Exercise.fromJson(r)).toList();
  }

  Future<List<WorkoutTemplate>> fetchMyTemplates() async {
    final rows = await supabase
        .from('workout_templates')
        .select()
        .order('created_at', ascending: false);
    return rows.map((r) => WorkoutTemplate.fromJson(r)).toList();
  }

  /// Max 7 templates per user — enforced server-side by
  /// `enforce_max_workout_templates()`; this call will throw a Postgres
  /// exception if the 8th is attempted, surface that error to the user
  /// rather than pre-counting client-side (avoids a race).
  Future<WorkoutTemplate> createTemplate({required String name, String? category}) async {
    final row = await supabase
        .from('workout_templates')
        .insert({
          'user_id': supabase.auth.currentUser!.id,
          'name': name,
          'category': category,
        })
        .select()
        .single();
    return WorkoutTemplate.fromJson(row);
  }

  Future<List<WorkoutTemplateExercise>> fetchTemplateExercises(String templateId) async {
    final rows = await supabase
        .from('workout_template_exercises')
        .select()
        .eq('template_id', templateId)
        .order('order_index');
    return rows.map((r) => WorkoutTemplateExercise.fromJson(r)).toList();
  }

  Future<WorkoutLog> startWorkoutLog({String? templateId}) async {
    final row = await supabase
        .from('workout_logs')
        .insert({
          'user_id': supabase.auth.currentUser!.id,
          'template_id': templateId,
        })
        .select()
        .single();
    return WorkoutLog.fromJson(row);
  }

  Future<WorkoutLogExercise> logExercise({
    required String workoutLogId,
    required String exerciseId,
    required int orderIndex,
    int? groupKey,
    bool isWarmup = false,
  }) async {
    final row = await supabase
        .from('workout_log_exercises')
        .insert({
          'workout_log_id': workoutLogId,
          'exercise_id': exerciseId,
          'order_index': orderIndex,
          'group_key': groupKey,
          'is_warmup': isWarmup,
        })
        .select()
        .single();
    return WorkoutLogExercise.fromJson(row);
  }

  /// Logging a set here fires the PR trigger server-side automatically.
  Future<WorkoutLogSet> logSet({
    required String workoutLogExerciseId,
    required int setNumber,
    int? reps,
    num? weightKg,
    int? holdSeconds,
  }) async {
    final row = await supabase
        .from('workout_log_sets')
        .insert({
          'workout_log_exercise_id': workoutLogExerciseId,
          'set_number': setNumber,
          'reps': reps,
          'weight_kg': weightKg,
          'hold_seconds': holdSeconds,
        })
        .select()
        .single();
    return WorkoutLogSet.fromJson(row);
  }

  /// Setting completed_at fires `handle_workout_log_completed()`
  /// server-side — bumps the streak and posts to the activity feed.
  /// Don't compute streaks/activity client-side.
  Future<void> completeWorkoutLog(String workoutLogId, {int? durationSeconds}) async {
    await supabase.from('workout_logs').update({
      'completed_at': DateTime.now().toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    }).eq('id', workoutLogId);
  }

  Future<List<WorkoutLog>> fetchRecentLogs({int limit = 14}) async {
    final rows = await supabase
        .from('workout_logs')
        .select()
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map((r) => WorkoutLog.fromJson(r)).toList();
  }

  Future<List<PersonalRecord>> fetchMyPersonalRecords() async {
    final rows = await supabase.from('personal_records').select();
    return rows.map((r) => PersonalRecord.fromJson(r)).toList();
  }

  /// Single row (or null if the user hasn't logged anything yet — the row
  /// is only created by `bump_streak()` on first completion).
  Future<UserStreak?> fetchMyStreak() async {
    final rows = await supabase
        .from('user_streaks')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return UserStreak.fromJson(rows.first);
  }
}

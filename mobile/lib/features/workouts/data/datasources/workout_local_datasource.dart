import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/active_workout.dart';
import '../../domain/entities/pending_workout.dart';

/// On-device storage for the TRAIN logger, keyed per user:
///
/// * the in-progress workout — written on every change so the app can be
///   killed mid-workout and offer "Resume workout";
/// * finished workouts waiting to reach Supabase (offline retry queue).
class WorkoutLocalDataSource {
  WorkoutLocalDataSource([Future<SharedPreferences> Function()? prefs])
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static String _activeKey(String userId) => 'train.active_workout.v1.$userId';
  static String _pendingKey(String userId) => 'train.pending_workouts.v1.$userId';

  Future<ActiveWorkout?> loadActive(String userId) async {
    final raw = (await _prefs()).getString(_activeKey(userId));
    if (raw == null) return null;
    try {
      return ActiveWorkout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Unreadable (e.g. written by an incompatible build): don't crash the
      // Workouts tab over it.
      return null;
    }
  }

  Future<void> saveActive(ActiveWorkout workout) async {
    await (await _prefs())
        .setString(_activeKey(workout.userId), jsonEncode(workout.toJson()));
  }

  Future<void> clearActive(String userId) async {
    await (await _prefs()).remove(_activeKey(userId));
  }

  Future<List<PendingWorkout>> loadPending(String userId) async {
    final raw = (await _prefs()).getStringList(_pendingKey(userId)) ?? const [];
    return [
      for (final item in raw)
        PendingWorkout.fromJson(jsonDecode(item) as Map<String, dynamic>),
    ];
  }

  Future<void> savePending(String userId, List<PendingWorkout> items) async {
    await (await _prefs()).setStringList(
      _pendingKey(userId),
      [for (final p in items) jsonEncode(p.toJson())],
    );
  }
}

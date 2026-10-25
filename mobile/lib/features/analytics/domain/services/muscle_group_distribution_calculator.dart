import '../../../muscle_map/domain/entities/muscle.dart';
import '../../../muscle_map/domain/entities/muscle_activity.dart';
import '../../../muscle_map/domain/services/muscle_mapping.dart';
import '../entities/muscle_group_distribution.dart';

/// Turns completed workout logs and the library's exercise → muscle-group
/// links into working sets per muscle group.
///
/// Same inputs as the hologram (`MuscleActivityCalculator`), grouped by the
/// library's own `muscle_groups` instead of drawn body regions. Only
/// completed workouts inside the range count; unknown group names are
/// skipped and their exercises reported, never guessed.
abstract final class MuscleGroupDistributionCalculator {
  /// Display label + region per canonical `muscle_groups.name`. Keys match
  /// [MuscleMapping.groups].
  static const Map<String, (String, BodyRegion)> groupInfo = {
    'abdominals': ('Abs', BodyRegion.core),
    'lower back': ('Lower back', BodyRegion.core),
    'abductors': ('Abductors', BodyRegion.lower),
    'adductors': ('Adductors', BodyRegion.lower),
    'calves': ('Calves', BodyRegion.lower),
    'glutes': ('Glutes', BodyRegion.lower),
    'hamstrings': ('Hamstrings', BodyRegion.lower),
    'quadriceps': ('Quads', BodyRegion.lower),
    'biceps': ('Biceps', BodyRegion.upper),
    'chest': ('Chest', BodyRegion.upper),
    'forearms': ('Forearms', BodyRegion.upper),
    'lats': ('Lats', BodyRegion.upper),
    'middle back': ('Mid back', BodyRegion.upper),
    'neck': ('Neck', BodyRegion.upper),
    'shoulders': ('Shoulders', BodyRegion.upper),
    'traps': ('Traps', BodyRegion.upper),
    'triceps': ('Triceps', BodyRegion.upper),
  };

  /// Canonical library name for [name] (case, `_`/`-` and the aliases in
  /// [MuscleMapping.aliases] tolerated); null when unknown.
  static String? canonicalGroup(String name) {
    final key = MuscleMapping.normalize(name);
    if (groupInfo.containsKey(key)) return key;
    final alias = MuscleMapping.aliases[key];
    return alias != null && groupInfo.containsKey(alias) ? alias : null;
  }

  /// Groups an exercise works, primary winning over secondary when an
  /// exercise lists the same group twice.
  static Map<String, Involvement> involvement(Iterable<MuscleLink> links) {
    final out = <String, Involvement>{};
    for (final link in links) {
      final group = canonicalGroup(link.groupName);
      if (group == null) continue;
      if (link.isPrimary) {
        out[group] = Involvement.primary;
      } else {
        out.putIfAbsent(group, () => Involvement.secondary);
      }
    }
    return out;
  }

  static MuscleGroupDistribution compute({
    required List<CompletedWorkoutRecord> workouts,
    required Map<String, List<MuscleLink>> linksByExercise,
    required DistributionRange range,
    required DateTime now,
  }) {
    final since = now.subtract(Duration(days: range.days));
    final bucketDays = range.days <= 7 ? 1 : 7;
    final bucketCount = (range.days / bucketDays).ceil();
    // Buckets end today (inclusive); oldest first. Built from calendar
    // fields so a DST change can't shift a start off midnight.
    final bucketStarts = [
      for (var i = bucketCount - 1; i >= 0; i--)
        DateTime(now.year, now.month,
            now.day - (i * bucketDays + bucketDays - 1)),
    ];

    final primary = <String, int>{};
    final secondary = <String, int>{};
    final exerciseSets = <String, Map<String, int>>{};
    final sessions = <String, List<GroupSession>>{};
    final buckets = <String, List<int>>{};
    final unmapped = <String>{};
    var workoutCount = 0;
    var workingSets = 0;

    for (final w in workouts) {
      final done = w.completedAt;
      if (done == null || done.isBefore(since) || done.isAfter(now)) continue;
      workoutCount++;
      // The range starts at `now` minus N days, so its first calendar day is
      // partial and can fall one step before the oldest bucket — fold it in.
      final rawBucket =
          bucketCount - 1 - (daysBetween(done, now) ~/ bucketDays);
      final bucket = rawBucket < 0
          ? 0
          : (rawBucket > bucketCount - 1 ? bucketCount - 1 : rawBucket);

      final setsThisWorkout = <String, int>{};
      final namesThisWorkout = <String, List<String>>{};
      for (final ex in w.exercises) {
        if (ex.workingSets <= 0) continue;
        final groups = involvement(linksByExercise[ex.exerciseId] ?? const []);
        if (groups.isEmpty) {
          unmapped.add(ex.exerciseName);
          continue;
        }
        workingSets += ex.workingSets;
        groups.forEach((group, kind) {
          final isPrimary = kind == Involvement.primary;
          final target = isPrimary ? primary : secondary;
          target[group] = (target[group] ?? 0) + ex.workingSets;
          final perEx = exerciseSets.putIfAbsent(group, () => {});
          perEx[ex.exerciseName] = (perEx[ex.exerciseName] ?? 0) + ex.workingSets;
          setsThisWorkout[group] = (setsThisWorkout[group] ?? 0) + ex.workingSets;
          final names = namesThisWorkout.putIfAbsent(group, () => []);
          if (!names.contains(ex.exerciseName)) names.add(ex.exerciseName);
          if (isPrimary) {
            final b = buckets.putIfAbsent(
                group, () => List<int>.filled(bucketCount, 0));
            b[bucket] += ex.workingSets;
          }
        });
      }
      setsThisWorkout.forEach((group, sets) {
        sessions.putIfAbsent(group, () => []).add(GroupSession(
              workoutId: w.id,
              date: done,
              sets: sets,
              exerciseNames: namesThisWorkout[group]!,
            ));
      });
    }

    final stats = <MuscleGroupStat>[
      for (final group in {...primary.keys, ...secondary.keys})
        MuscleGroupStat(
          group: group,
          label: groupInfo[group]!.$1,
          region: groupInfo[group]!.$2,
          primarySets: primary[group] ?? 0,
          secondarySets: secondary[group] ?? 0,
          exerciseSets: _sortedDesc(exerciseSets[group] ?? const {}),
          sessions: [...?sessions[group]]
            ..sort((a, b) => b.date.compareTo(a.date)),
          bucketSets: buckets[group] ?? List<int>.filled(bucketCount, 0),
        ),
    ]..sort((a, b) {
        final byPrimary = b.primarySets.compareTo(a.primarySets);
        if (byPrimary != 0) return byPrimary;
        final byTotal = b.totalSets.compareTo(a.totalSets);
        return byTotal != 0 ? byTotal : a.label.compareTo(b.label);
      });

    return MuscleGroupDistribution(
      range: range,
      since: since,
      groups: stats,
      workoutCount: workoutCount,
      workingSets: workingSets,
      unmappedExercises: unmapped,
      bucketDays: bucketDays,
      bucketStarts: bucketStarts,
    );
  }

  /// Whole calendar days from [from] to [to], immune to DST shifts.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  static Map<String, int> _sortedDesc(Map<String, int> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }
}

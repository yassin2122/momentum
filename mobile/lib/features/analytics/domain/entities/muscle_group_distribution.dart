/// Where a library muscle group sits on the body, for the upper / lower /
/// core split.
enum BodyRegion {
  upper('Upper body'),
  lower('Lower body'),
  core('Core');

  const BodyRegion(this.label);

  final String label;
}

/// The analytics date filters.
enum DistributionRange {
  days7(7, '7D', 'last 7 days'),
  weeks4(28, '4W', 'last 4 weeks'),
  weeks12(84, '12W', 'last 12 weeks');

  const DistributionRange(this.days, this.short, this.phrase);

  final int days;
  final String short;

  /// "last 4 weeks" — reads inside a sentence.
  final String phrase;
}

/// One workout's working sets for a muscle group.
final class GroupSession {
  const GroupSession({
    required this.workoutId,
    required this.date,
    required this.sets,
    required this.exerciseNames,
  });

  final String workoutId;
  final DateTime date;
  final int sets;
  final List<String> exerciseNames;
}

/// Working sets for one library muscle group (`muscle_groups.name`)
/// inside the chosen range.
final class MuscleGroupStat {
  const MuscleGroupStat({
    required this.group,
    required this.label,
    required this.region,
    required this.primarySets,
    required this.secondarySets,
    required this.exerciseSets,
    required this.sessions,
    required this.bucketSets,
  });

  /// Canonical library name, e.g. `middle back`.
  final String group;
  final String label;
  final BodyRegion region;

  /// Sets of exercises whose primary target is this group.
  final int primarySets;

  /// Sets where this group only assists (secondary muscle).
  final int secondarySets;

  /// Exercise name → sets that hit this group, most first.
  final Map<String, int> exerciseSets;

  /// Newest first.
  final List<GroupSession> sessions;

  /// Primary sets per time bucket, oldest first (see
  /// [MuscleGroupDistribution.bucketStarts]).
  final List<int> bucketSets;

  int get totalSets => primarySets + secondarySets;
  DateTime? get lastTrained => sessions.isEmpty ? null : sessions.first.date;
}

/// Working sets per muscle group from completed workouts.
final class MuscleGroupDistribution {
  const MuscleGroupDistribution({
    required this.range,
    required this.since,
    required this.groups,
    required this.workoutCount,
    required this.workingSets,
    required this.unmappedExercises,
    required this.bucketDays,
    required this.bucketStarts,
  });

  final DistributionRange range;
  final DateTime since;

  /// Trained groups, most primary sets first.
  final List<MuscleGroupStat> groups;

  /// Completed workouts in range.
  final int workoutCount;

  /// Completed working sets in range, each set counted once (a set can hit
  /// several groups, so this is less than the sum over groups).
  final int workingSets;

  /// Exercises logged in range with no muscle data (shown, not guessed).
  final Set<String> unmappedExercises;

  /// 1 for the 7-day range (daily bars), 7 otherwise (weekly bars).
  final int bucketDays;

  /// Start of each bucket, oldest first.
  final List<DateTime> bucketStarts;

  bool get isEmpty => groups.isEmpty;

  int get totalPrimarySets =>
      groups.fold(0, (sum, g) => sum + g.primarySets);

  /// Share of all primary sets (0–1).
  double shareOf(MuscleGroupStat g) {
    final total = totalPrimarySets;
    return total == 0 ? 0 : g.primarySets / total;
  }

  /// Primary sets per body region.
  Map<BodyRegion, int> get regionSets => {
        for (final r in BodyRegion.values)
          r: groups
              .where((g) => g.region == r)
              .fold(0, (sum, g) => sum + g.primarySets),
      };

  MuscleGroupStat? byGroup(String group) {
    for (final g in groups) {
      if (g.group == group) return g;
    }
    return null;
  }
}

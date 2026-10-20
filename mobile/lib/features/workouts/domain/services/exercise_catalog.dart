import '../entities/trackable_exercise.dart';

/// Coarse body part for the exercise picker's filter chips, mapped onto the
/// library's `muscle_groups.name` values.
enum BodyPart {
  chest('Chest', ['chest']),
  back('Back', ['lats', 'middle back', 'lower back', 'traps']),
  shoulders('Shoulders', ['shoulders']),
  arms('Arms', ['biceps', 'triceps', 'forearms']),
  legs('Legs',
      ['quadriceps', 'hamstrings', 'glutes', 'calves', 'adductors', 'abductors']),
  core('Core', ['abdominals']);

  const BodyPart(this.label, this.muscleGroups);

  final String label;
  final List<String> muscleGroups;

  /// The part a library muscle-group name belongs to, if any.
  static BodyPart? ofMuscleGroup(String? group) {
    if (group == null) return null;
    final g = group.trim().toLowerCase();
    for (final p in values) {
      if (p.muscleGroups.contains(g)) return p;
    }
    return null;
  }
}

/// The well-known lifts shown first in the picker, so a lifter sees
/// "Barbell Bench Press" before "3/4 Sit-Up". Slugs are free-exercise-db
/// ids run through the sync script's `toSlug` — every one exists in
/// `free-exercise-db/exercises/`. Order within a part is display order.
abstract final class ExerciseCatalog {
  static const Map<BodyPart, List<String>> mainLifts = {
    BodyPart.chest: [
      'barbell-bench-press-medium-grip',
      'barbell-incline-bench-press-medium-grip',
      'dumbbell-bench-press',
      'incline-dumbbell-press',
      'dumbbell-flyes',
      'cable-crossover',
      'dips-chest-version',
      'pushups',
    ],
    BodyPart.back: [
      'barbell-deadlift',
      'pullups',
      'chin-up',
      'wide-grip-lat-pulldown',
      'bent-over-barbell-row',
      'one-arm-dumbbell-row',
      'seated-cable-rows',
      't-bar-row-with-handle',
      'inverted-row',
      'barbell-shrug',
    ],
    BodyPart.shoulders: [
      'standing-military-press',
      'dumbbell-shoulder-press',
      'arnold-dumbbell-press',
      'side-lateral-raise',
      'face-pull',
      'reverse-flyes',
      'upright-barbell-row',
    ],
    BodyPart.arms: [
      'barbell-curl',
      'dumbbell-bicep-curl',
      'hammer-curls',
      'ez-bar-curl',
      'preacher-curl',
      'triceps-pushdown',
      'triceps-pushdown-rope-attachment',
      'close-grip-barbell-bench-press',
      'ez-bar-skullcrusher',
      'dips-triceps-version',
    ],
    BodyPart.legs: [
      'barbell-full-squat',
      'barbell-squat',
      'front-squat-clean-grip',
      'leg-press',
      'romanian-deadlift',
      'dumbbell-lunges',
      'split-squat-with-dumbbells',
      'goblet-squat',
      'hack-squat',
      'leg-extensions',
      'lying-leg-curls',
      'barbell-hip-thrust',
      'barbell-glute-bridge',
      'standing-calf-raises',
      'seated-calf-raise',
      'sumo-deadlift',
    ],
    BodyPart.core: [
      'plank',
      'hanging-leg-raise',
      'cable-crunch',
      'ab-roller',
      'crunches',
      'russian-twist',
    ],
  };

  /// Every main-lift slug, in display order.
  static final List<String> allMainSlugs = [
    for (final list in mainLifts.values) ...list,
  ];

  static final Map<String, int> _mainRank = {
    for (var i = 0; i < allMainSlugs.length; i++) allMainSlugs[i]: i,
  };

  static bool isMain(TrackableExercise e) =>
      e.slug != null && _mainRank.containsKey(e.slug);

  /// [exercises] (fetched by slug) in main-lift display order, optionally
  /// only those for [part]. Missing slugs are simply skipped.
  static List<TrackableExercise> orderMain(
    Iterable<TrackableExercise> exercises, {
    BodyPart? part,
  }) {
    final allowed = part == null ? null : mainLifts[part]!.toSet();
    final list = [
      for (final e in exercises)
        if (isMain(e) && (allowed == null || allowed.contains(e.slug))) e,
    ]..sort((a, b) => _mainRank[a.slug]!.compareTo(_mainRank[b.slug]!));
    return list;
  }

  /// Search ranking: your custom exercises and main lifts first, then names
  /// that start with the query, then ones with a photo, then A–Z.
  static List<TrackableExercise> rankForSearch(
    Iterable<TrackableExercise> exercises,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    int score(TrackableExercise e) {
      final name = e.name.toLowerCase();
      var s = 0;
      if (!e.isCustom) s += 8;
      if (!isMain(e)) s += 4;
      if (q.isNotEmpty && !name.startsWith(q)) {
        s += name.split(RegExp(r'[\s\-/]+')).any((w) => w.startsWith(q)) ? 1 : 2;
      }
      if (e.imageUrl == null) s += 1;
      return s;
    }

    return exercises.toList()
      ..sort((a, b) {
        final byScore = score(a).compareTo(score(b));
        return byScore != 0
            ? byScore
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
}

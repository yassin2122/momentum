import '../entities/muscle.dart';

/// One `exercise_muscle_groups` row: a library muscle group name and
/// whether it is the exercise's primary target.
final class MuscleLink {
  const MuscleLink({required this.groupName, required this.isPrimary});

  final String groupName;
  final bool isPrimary;
}

/// Maps library muscle-group names (the `muscle_groups` table) and common
/// aliases onto body-map [Muscle] regions.
///
/// The library is coarser than the map: `shoulders` has no deltoid heads
/// and `abdominals` has no upper/lower/oblique split, so those groups light
/// every region they cover. Unknown names map to nothing (missing data is
/// skipped, never guessed).
abstract final class MuscleMapping {
  /// Canonical library names → regions. Keys match `muscle_groups.name`.
  static const Map<String, Set<Muscle>> groups = {
    'abdominals': {Muscle.upperAbs, Muscle.lowerAbs, Muscle.obliques},
    'abductors': {Muscle.glutes},
    'adductors': {Muscle.adductors},
    'biceps': {Muscle.biceps},
    'calves': {Muscle.calves},
    'chest': {Muscle.chest},
    'forearms': {Muscle.forearms},
    'glutes': {Muscle.glutes},
    'hamstrings': {Muscle.hamstrings},
    'lats': {Muscle.lats},
    'lower back': {Muscle.lowerBack},
    'middle back': {Muscle.upperBack},
    'neck': {Muscle.traps},
    'quadriceps': {Muscle.quadriceps},
    'shoulders': {
      Muscle.deltAnterior,
      Muscle.deltLateral,
      Muscle.deltPosterior,
    },
    'traps': {Muscle.traps},
    'triceps': {Muscle.triceps},
  };

  /// Alternative spellings → canonical library name.
  static const Map<String, String> aliases = {
    'abs': 'abdominals',
    'abdominal': 'abdominals',
    'core': 'abdominals',
    'abductor': 'abductors',
    'hip abductors': 'abductors',
    'adductor': 'adductors',
    'inner thigh': 'adductors',
    'bicep': 'biceps',
    'calf': 'calves',
    'pecs': 'chest',
    'pectorals': 'chest',
    'forearm': 'forearms',
    'glute': 'glutes',
    'gluteus': 'glutes',
    'hamstring': 'hamstrings',
    'hams': 'hamstrings',
    'lat': 'lats',
    'latissimus dorsi': 'lats',
    'lowerback': 'lower back',
    'erector spinae': 'lower back',
    'upper back': 'middle back',
    'mid back': 'middle back',
    'rhomboids': 'middle back',
    'quads': 'quadriceps',
    'quad': 'quadriceps',
    'shoulder': 'shoulders',
    'delts': 'shoulders',
    'deltoids': 'shoulders',
    'trap': 'traps',
    'trapezius': 'traps',
    'tricep': 'triceps',
  };

  /// Lower-cases, trims and turns `_`/`-` and repeated spaces into one
  /// space, so `Lower_Back` and `lower-back` match `lower back`.
  static String normalize(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Regions for one muscle-group name; empty when unknown.
  static Set<Muscle> musclesFor(String groupName) {
    final key = normalize(groupName);
    return groups[key] ?? groups[aliases[key]] ?? const {};
  }

  /// Regions an exercise works, from its links. A region that is primary
  /// through one link stays primary even if another link lists it as
  /// secondary (e.g. `abductors` → glutes alongside primary `glutes`).
  static Map<Muscle, Involvement> involvement(Iterable<MuscleLink> links) {
    final result = <Muscle, Involvement>{};
    for (final link in links) {
      for (final muscle in musclesFor(link.groupName)) {
        if (link.isPrimary) {
          result[muscle] = Involvement.primary;
        } else {
          result.putIfAbsent(muscle, () => Involvement.secondary);
        }
      }
    }
    return result;
  }

  /// Regions a whole template works: the union over its exercises, primary
  /// winning over secondary.
  static Map<Muscle, Involvement> templateInvolvement(
    Iterable<String> exerciseIds,
    Map<String, List<MuscleLink>> linksByExercise,
  ) {
    final result = <Muscle, Involvement>{};
    for (final id in exerciseIds) {
      involvement(linksByExercise[id] ?? const []).forEach((muscle, kind) {
        if (kind == Involvement.primary) {
          result[muscle] = Involvement.primary;
        } else {
          result.putIfAbsent(muscle, () => Involvement.secondary);
        }
      });
    }
    return result;
  }
}

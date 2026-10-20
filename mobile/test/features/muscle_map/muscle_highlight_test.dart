import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_highlight.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_mapping.dart';

// Exercise ids → library `exercise_muscle_groups` links, as the
// repository returns them.
const _links = <String, List<MuscleLink>>{
  'bench-press': [
    MuscleLink(groupName: 'chest', isPrimary: true),
    MuscleLink(groupName: 'triceps', isPrimary: false),
    MuscleLink(groupName: 'shoulders', isPrimary: false),
  ],
  'pull-up': [
    MuscleLink(groupName: 'lats', isPrimary: true),
    MuscleLink(groupName: 'biceps', isPrimary: false),
    MuscleLink(groupName: 'middle back', isPrimary: false),
  ],
  'dips': [
    MuscleLink(groupName: 'triceps', isPrimary: true),
    MuscleLink(groupName: 'chest', isPrimary: false),
  ],
  'hyperextension': [MuscleLink(groupName: 'lower back', isPrimary: true)],
};

void main() {
  group('exercise → muscle highlight', () {
    test('primary muscles full, secondary dimmer', () {
      expect(MuscleHighlight.forExercise(_links['bench-press']!), {
        Muscle.chest: MuscleHighlight.primary,
        Muscle.triceps: MuscleHighlight.secondary,
        Muscle.deltAnterior: MuscleHighlight.secondary,
        Muscle.deltLateral: MuscleHighlight.secondary,
        Muscle.deltPosterior: MuscleHighlight.secondary,
      });
    });

    test('library aliases resolve (middle back → upper back)', () {
      final m = MuscleHighlight.forExercise(_links['pull-up']!);
      expect(m[Muscle.lats], MuscleHighlight.primary);
      expect(m[Muscle.biceps], MuscleHighlight.secondary);
      expect(m[Muscle.upperBack], MuscleHighlight.secondary);
    });

    test('an exercise without muscle data lights nothing', () {
      expect(MuscleHighlight.forExercise(const []), isEmpty);
      expect(
        MuscleHighlight.forExercise(
            const [MuscleLink(groupName: 'elbows', isPrimary: true)]),
        isEmpty,
      );
    });

    test('every highlighted muscle except lower back is drawable', () {
      final all = MuscleHighlight.forWorkout(
        exerciseIds: _links.keys,
        linksByExercise: _links,
      );
      expect(MuscleHighlight.undrawn(all), {Muscle.lowerBack});
    });
  });

  group('workout highlight state', () {
    test('without a focus every exercise lights; brightest wins', () {
      final m = MuscleHighlight.forWorkout(
        exerciseIds: ['bench-press', 'dips'],
        linksByExercise: _links,
      );
      // Chest: primary in bench, secondary in dips → primary.
      expect(m[Muscle.chest], MuscleHighlight.primary);
      // Triceps: secondary in bench, primary in dips → primary.
      expect(m[Muscle.triceps], MuscleHighlight.primary);
    });

    test('changing the focused exercise moves the bright highlight', () {
      Map<Muscle, double> focus(String id) => MuscleHighlight.forWorkout(
            exerciseIds: ['bench-press', 'pull-up'],
            linksByExercise: _links,
            focusExerciseId: id,
          );

      final onBench = focus('bench-press');
      expect(onBench[Muscle.chest], MuscleHighlight.primary);
      expect(onBench[Muscle.lats], MuscleHighlight.context);

      final onPullUp = focus('pull-up');
      expect(onPullUp[Muscle.lats], MuscleHighlight.primary);
      expect(onPullUp[Muscle.chest], MuscleHighlight.context);
      expect(onPullUp, isNot(equals(onBench)));
    });

    test('unknown exercise ids are ignored', () {
      expect(
        MuscleHighlight.forWorkout(
          exerciseIds: ['missing'],
          linksByExercise: _links,
        ),
        isEmpty,
      );
    });

    test('best view follows where the highlight is', () {
      expect(
        MuscleHighlight.bestView(
            MuscleHighlight.forExercise(_links['bench-press']!)),
        BodyView.front,
      );
      expect(
        MuscleHighlight.bestView(const {
          Muscle.upperBack: 1,
          Muscle.deltPosterior: 1,
        }),
        BodyView.back,
      );
      expect(MuscleHighlight.bestView(const {}), BodyView.front);
    });
  });
}

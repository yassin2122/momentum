import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/workouts/domain/entities/trackable_exercise.dart';
import 'package:grit/features/workouts/domain/entities/workout_enums.dart';
import 'package:grit/features/workouts/domain/services/exercise_catalog.dart';

TrackableExercise ex(
  String name, {
  String? slug,
  bool custom = false,
  String? image = 'X/0.jpg',
  String? muscle,
}) =>
    TrackableExercise(
      id: name,
      name: name,
      trackingType: TrackingType.weightReps,
      slug: slug,
      isCustom: custom,
      imagePath: image,
      primaryMuscle: muscle,
    );

void main() {
  group('ExerciseCatalog', () {
    test('main-lift slugs are unique and every body part has some', () {
      final all = ExerciseCatalog.allMainSlugs;
      expect(all.toSet(), hasLength(all.length));
      for (final part in BodyPart.values) {
        expect(ExerciseCatalog.mainLifts[part], isNotEmpty, reason: part.name);
      }
    });

    test('main lifts come out in display order, filtered by body part', () {
      final fetched = [
        ex('Pushups', slug: 'pushups'),
        ex('Barbell Squat', slug: 'barbell-squat'),
        ex('Barbell Bench Press', slug: 'barbell-bench-press-medium-grip'),
        ex('3/4 Sit-Up', slug: '3-4-sit-up'), // not a main lift
      ];
      expect(
        ExerciseCatalog.orderMain(fetched).map((e) => e.name),
        ['Barbell Bench Press', 'Pushups', 'Barbell Squat'],
      );
      expect(
        ExerciseCatalog.orderMain(fetched, part: BodyPart.legs)
            .map((e) => e.name),
        ['Barbell Squat'],
      );
    });

    test('search ranks custom, then main lifts, then prefix matches', () {
      final ranked = ExerciseCatalog.rankForSearch([
        ex('Alternating Deltoid Raise'),
        ex('Incline Bench Pull'),
        ex('Bench Dips'),
        ex('Barbell Bench Press', slug: 'barbell-bench-press-medium-grip'),
        ex('My Bench Variation', custom: true),
      ], 'bench');
      expect(ranked.map((e) => e.name).toList(), [
        'My Bench Variation',
        'Barbell Bench Press',
        'Bench Dips', // starts with the query
        'Incline Bench Pull', // a word starts with it
        'Alternating Deltoid Raise',
      ]);
    });

    test('exercises with photos rank above ones without', () {
      final ranked = ExerciseCatalog.rankForSearch([
        ex('Curl A', image: null),
        ex('Curl B'),
      ], 'curl');
      expect(ranked.first.name, 'Curl B');
    });

    test('body parts map from library muscle groups', () {
      expect(BodyPart.ofMuscleGroup('chest'), BodyPart.chest);
      expect(BodyPart.ofMuscleGroup('Middle Back'), BodyPart.back);
      expect(BodyPart.ofMuscleGroup('quadriceps'), BodyPart.legs);
      expect(BodyPart.ofMuscleGroup('abdominals'), BodyPart.core);
      expect(BodyPart.ofMuscleGroup(null), isNull);
      expect(BodyPart.ofMuscleGroup('neck'), isNull);
    });
  });

  group('TrackableExercise.fromJson', () {
    test('reads photo, slug and primary muscle from the library row', () {
      final e = TrackableExercise.fromJson({
        'id': 'e1',
        'name': 'Barbell Bench Press - Medium Grip',
        'tracking_type': 'weight_reps',
        'bw_factor': 0,
        'equipment': 'barbell',
        'is_custom': false,
        'slug': 'barbell-bench-press-medium-grip',
        'images': ['Barbell_Bench_Press_-_Medium_Grip/0.jpg', 'x/1.jpg'],
        'exercise_muscle_groups': [
          {'is_primary': false, 'muscle_groups': {'name': 'triceps'}},
          {'is_primary': true, 'muscle_groups': {'name': 'chest'}},
        ],
      });
      expect(e.slug, 'barbell-bench-press-medium-grip');
      expect(e.primaryMuscle, 'chest');
      expect(e.imageUrl, endsWith('Barbell_Bench_Press_-_Medium_Grip/0.jpg'));
      expect(e.imageUrl, startsWith('https://'));
    });

    test('survives a toJson round trip (saved active workouts)', () {
      final e = ex('Squat', slug: 'barbell-squat', muscle: 'quadriceps');
      final back = TrackableExercise.fromJson(e.toJson());
      expect(back.slug, e.slug);
      expect(back.imagePath, e.imagePath);
      expect(back.primaryMuscle, 'quadriceps');
    });

    test('old saved rows without the new keys still load', () {
      final e = TrackableExercise.fromJson({
        'id': 'e2',
        'name': 'Custom Thing',
        'tracking_type': 'weight_reps',
        'is_custom': true,
      });
      expect(e.imageUrl, isNull);
      expect(e.primaryMuscle, isNull);
    });
  });
}

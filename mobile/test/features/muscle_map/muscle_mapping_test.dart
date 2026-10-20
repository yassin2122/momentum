import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_mapping.dart';

void main() {
  group('MuscleMapping.musclesFor', () {
    test('maps every library muscle group to at least one region', () {
      const library = [
        'abdominals', 'abductors', 'adductors', 'biceps', 'calves', 'chest',
        'forearms', 'glutes', 'hamstrings', 'lats', 'lower back',
        'middle back', 'neck', 'quadriceps', 'shoulders', 'traps', 'triceps',
      ];
      for (final name in library) {
        expect(MuscleMapping.musclesFor(name), isNotEmpty, reason: name);
      }
    });

    test('shared groups light every region they cover', () {
      expect(MuscleMapping.musclesFor('shoulders'), {
        Muscle.deltAnterior,
        Muscle.deltLateral,
        Muscle.deltPosterior,
      });
      expect(MuscleMapping.musclesFor('abdominals'),
          {Muscle.upperAbs, Muscle.lowerAbs, Muscle.obliques});
    });

    test('normalizes case, separators and aliases', () {
      expect(MuscleMapping.musclesFor('  Lower_Back '), {Muscle.lowerBack});
      expect(MuscleMapping.musclesFor('lower-back'), {Muscle.lowerBack});
      expect(MuscleMapping.musclesFor('Quads'), {Muscle.quadriceps});
      expect(MuscleMapping.musclesFor('latissimus dorsi'), {Muscle.lats});
      expect(MuscleMapping.musclesFor('upper back'), {Muscle.upperBack});
    });

    test('unknown names map to nothing', () {
      expect(MuscleMapping.musclesFor('elbows'), isEmpty);
      expect(MuscleMapping.musclesFor(''), isEmpty);
    });
  });

  group('MuscleMapping.involvement', () {
    test('primary wins over secondary for the same region', () {
      final m = MuscleMapping.involvement(const [
        MuscleLink(groupName: 'abductors', isPrimary: false), // → glutes
        MuscleLink(groupName: 'glutes', isPrimary: true),
        MuscleLink(groupName: 'hamstrings', isPrimary: false),
      ]);
      expect(m[Muscle.glutes], Involvement.primary);
      expect(m[Muscle.hamstrings], Involvement.secondary);
    });

    test('template involvement is the union across exercises', () {
      final links = {
        'bench': const [
          MuscleLink(groupName: 'chest', isPrimary: true),
          MuscleLink(groupName: 'triceps', isPrimary: false),
        ],
        'dips': const [MuscleLink(groupName: 'triceps', isPrimary: true)],
      };
      final m = MuscleMapping.templateInvolvement(
          ['bench', 'dips', 'missing'], links);
      expect(m, {
        Muscle.chest: Involvement.primary,
        Muscle.triceps: Involvement.primary,
      });
    });
  });
}

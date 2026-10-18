import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/features/muscle_map/domain/entities/muscle.dart';
import 'package:gym_app/features/muscle_map/presentation/body/body_geometry.dart';
import 'package:gym_app/features/muscle_map/presentation/body/svg_path_parser.dart';

void main() {
  test('parser rejects unsupported commands', () {
    expect(() => parseSvgPath('M0,0 A1,1 0 0 1 2,2'), throwsFormatException);
    expect(() => parseSvgPath('M0,0 L1'), throwsFormatException);
  });

  test('every muscle has a shape in each view it claims', () {
    for (final muscle in Muscle.values) {
      for (final view in muscle.views) {
        expect(
          BodyGeometry.shapes(view).any((s) => s.muscle == muscle),
          isTrue,
          reason: '${muscle.name} on ${view.name}',
        );
      }
    }
  });

  test('every shape sits inside the view box and the silhouette', () {
    final box = Offset.zero & BodyGeometry.viewBox;
    final body = BodyGeometry.silhouette.getBounds();
    for (final view in BodyView.values) {
      for (final s in BodyGeometry.shapes(view)) {
        final b = s.path.getBounds();
        expect(box.contains(b.topLeft) && box.contains(b.bottomRight), isTrue,
            reason: s.muscle.name);
        expect(body.inflate(2).contains(b.center), isTrue,
            reason: s.muscle.name);
      }
    }
  });

  test('taps on both halves resolve to the same muscle', () {
    final left = BodyGeometry.hitTest(BodyView.front, const Offset(78, 112));
    final right = BodyGeometry.hitTest(BodyView.front, const Offset(122, 112));
    expect(left, Muscle.chest);
    expect(right, Muscle.chest);
    expect(BodyGeometry.hitTest(BodyView.front, const Offset(100, 160)),
        Muscle.upperAbs);
    expect(BodyGeometry.hitTest(BodyView.back, const Offset(100, 210)),
        Muscle.lowerBack);
    expect(BodyGeometry.hitTest(BodyView.front, const Offset(5, 5)), isNull);
  });

  test('fit keeps aspect ratio and centres', () {
    final fit = BodyGeometry.fit(const Size(400, 440));
    expect(fit.scale, 1);
    expect(fit.offset, const Offset(100, 0));
  });
}

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle.dart';
import 'package:grit/features/muscle_map/presentation/body/body_geometry.dart';
import 'package:grit/features/muscle_map/presentation/body/svg_path_parser.dart';

/// Parses the real bundled assets (tests run from mobile/).
BodyGeometry load(BodyView view) => BodyGeometry.parse(
      view,
      File(BodyGeometry.assetPaths[view]!).readAsStringSync(),
    );

/// A view-box point that hit-tests to [muscle], found by scanning its
/// shapes' bounds (null if every part is fully covered by other shapes).
Offset? tappablePoint(BodyGeometry g, Muscle muscle) {
  final b = g.regionPath(muscle)!.getBounds();
  for (var y = b.top; y <= b.bottom; y += 2) {
    for (var x = b.left; x <= b.right; x += 2) {
      final p = Offset(x, y);
      if (g.hitTest(p) == muscle) return p;
    }
  }
  return null;
}

void main() {
  group('parseSvgPath', () {
    test('supports the absolute commands the assets use, including H/V', () {
      final b = parseSvgPath('M0 0 H10 V20 L0 20 Z').getBounds();
      expect(b, const Rect.fromLTRB(0, 0, 10, 20));
    });

    test('rejects commands outside the subset', () {
      expect(() => parseSvgPath('M0,0 A1,1 0 0 1 2,2'), throwsFormatException);
      expect(() => parseSvgPath('M0,0 l1,1'), throwsFormatException);
      expect(() => parseSvgPath('M0,0 L1'), throwsFormatException);
    });
  });

  group('anatomy assets', () {
    final views = {for (final v in BodyView.values) v: load(v)};

    test('every muscle is drawn in exactly the views it claims', () {
      for (final view in BodyView.values) {
        for (final muscle in Muscle.values) {
          expect(
            views[view]!.muscles.contains(muscle),
            muscle.views.contains(view),
            reason: '${muscle.name} on ${view.name}',
          );
        }
      }
    });

    test('lower back is not drawn: the art has no erector spinae', () {
      expect(Muscle.lowerBack.views, isEmpty);
      for (final g in views.values) {
        expect(g.regionPath(Muscle.lowerBack), isNull);
      }
    });

    test('regions keep their stable anatomical ids, both sides', () {
      final front = views[BodyView.front]!;
      final back = views[BodyView.back]!;
      expect(front.partIds(Muscle.chest),
          unorderedEquals(['pectoralis_major_l', 'pectoralis_major_r']));
      expect(back.partIds(Muscle.deltPosterior),
          unorderedEquals(['posterior_deltoid_l', 'posterior_deltoid_r']));
      expect(back.partIds(Muscle.traps),
          unorderedEquals(['trapezius_upper_l', 'trapezius_upper_r']));
      expect(back.partIds(Muscle.hamstrings), hasLength(8));
      // Every paired muscle part has its mirror.
      for (final g in views.values) {
        for (final m in g.muscles) {
          final ids = g.partIds(m).toSet();
          for (final id in ids) {
            if (id.endsWith('_l')) {
              expect(ids, contains('${id.substring(0, id.length - 2)}_r'),
                  reason: '$id in ${g.view.name}');
            }
          }
        }
      }
    });

    test('ids are unique and every shape sits inside the view box', () {
      for (final g in views.values) {
        final ids = g.parts.map((p) => p.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: g.view.name);
        final box = (Offset.zero & g.viewBox).inflate(1);
        for (final p in g.parts) {
          final b = p.path.getBounds();
          expect(box.contains(b.topLeft) && box.contains(b.bottomRight), isTrue,
              reason: '${p.id} (${g.view.name})');
        }
      }
    });

    test('parts are in paint order', () {
      for (final g in views.values) {
        for (var i = 1; i < g.parts.length; i++) {
          expect(g.parts[i].z, greaterThan(g.parts[i - 1].z));
        }
      }
    });

    test('every drawn muscle can be tapped', () {
      for (final g in views.values) {
        for (final m in g.muscles) {
          expect(tappablePoint(g, m), isNotNull,
              reason: '${m.name} on ${g.view.name}');
        }
      }
    });

    test('paint order decides overlapping taps: upper traps over the '
        'whole trapezius', () {
      final back = views[BodyView.back]!;
      Path part(String id) => back.parts.firstWhere((p) => p.id == id).path;
      final upper = part('trapezius_upper_l');
      final whole = part('trapezius_middle_l'); // the full trapezius shape
      final b = upper.getBounds();
      var checked = 0;
      for (var y = b.top; y <= b.bottom; y += 4) {
        for (var x = b.left; x <= b.right; x += 4) {
          final p = Offset(x, y);
          if (upper.contains(p) && whole.contains(p)) {
            expect(back.hitTest(p), Muscle.traps, reason: '$p');
            checked++;
          }
        }
      }
      expect(checked, greaterThan(10));
    });

    test('taps outside the body hit nothing', () {
      for (final g in views.values) {
        expect(g.hitTest(const Offset(2, 2)), isNull);
        expect(g.hitTest(Offset(g.viewBox.width - 2, g.viewBox.height / 2)),
            isNull);
      }
    });

    test('an off-contract asset fails loudly', () {
      expect(
        () => BodyGeometry.parse(BodyView.front, '<svg viewBox="0 0 10 10">'
            '<path id="silhouette" d="M0 0 L1 1 Z"/>'
            '<g id="muscles"><g id="wings"><path id="x" d="M0 0 L1 1 Z"/>'
            '</g></g></svg>'),
        throwsFormatException,
      );
      expect(
        () => BodyGeometry.parse(BodyView.front, '<svg viewBox="0 0 10 10"></svg>'),
        throwsFormatException,
      );
    });

    test('fit keeps aspect ratio and centres', () {
      final g = views[BodyView.front]!;
      final fit = g.fit(Size(g.viewBox.width * 2, g.viewBox.height));
      expect(fit.scale, 1);
      expect(fit.offset, Offset(g.viewBox.width / 2, 0));
    });
  });
}

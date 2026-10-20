import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle.dart';
import 'package:grit/features/muscle_map/presentation/body/body_geometry.dart';
import 'package:grit/features/muscle_map/presentation/providers/muscle_map_providers.dart';
import 'package:grit/features/muscle_map/presentation/widgets/muscle_map_view.dart';

final _atlas = BodyAtlas({
  for (final v in BodyView.values)
    v: BodyGeometry.parse(v, File(BodyGeometry.assetPaths[v]!).readAsStringSync()),
});

const _size = Size(300, 580);

Widget _host(Widget child, {bool disableAnimations = false}) => ProviderScope(
      overrides: [bodyAtlasProvider.overrideWith((ref) => _atlas)],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox.fromSize(size: _size, child: child)),
        ),
      ),
    );

MuscleMapViewState _state(WidgetTester t) =>
    t.state<MuscleMapViewState>(find.byType(MuscleMapView));

void main() {
  testWidgets('renders the anatomy and starts unlit', (t) async {
    await t.pumpWidget(_host(const MuscleMapView(view: BodyView.front)));
    expect(find.byType(CustomPaint), findsWidgets);
    for (final m in Muscle.values) {
      expect(_state(t).lookOf(m), MuscleLook.idle);
    }
  });

  testWidgets('highlight changes animate to the target look', (t) async {
    await t.pumpWidget(_host(const MuscleMapView(view: BodyView.front)));

    await t.pumpWidget(_host(const MuscleMapView(
      view: BodyView.front,
      intensities: {Muscle.chest: 1, Muscle.triceps: 0.4},
    )));
    // Frame 0 of the transition: still the old look.
    expect(_state(t).lookOf(Muscle.chest), MuscleLook.idle);

    await t.pump(const Duration(milliseconds: 120));
    final mid = _state(t).lookOf(Muscle.chest);
    expect(mid.glow, greaterThan(0));
    expect(mid.glow, lessThan(MuscleMapView.targetLook(1).glow));

    await t.pumpAndSettle();
    expect(_state(t).lookOf(Muscle.chest), MuscleMapView.targetLook(1));
    expect(_state(t).lookOf(Muscle.triceps), MuscleMapView.targetLook(0.4));
    expect(_state(t).lookOf(Muscle.biceps), MuscleLook.idle);
    // Intensity-based: the stronger muscle glows more.
    expect(_state(t).lookOf(Muscle.chest).glow,
        greaterThan(_state(t).lookOf(Muscle.triceps).glow));

    // Switching exercise: chest fades out, lats light up.
    await t.pumpWidget(_host(const MuscleMapView(
      view: BodyView.front,
      intensities: {Muscle.lats: 1},
    )));
    await t.pumpAndSettle();
    expect(_state(t).lookOf(Muscle.chest), MuscleLook.idle);
    expect(_state(t).lookOf(Muscle.lats), MuscleMapView.targetLook(1));
  });

  testWidgets('selection overrides intensity', (t) async {
    await t.pumpWidget(_host(const MuscleMapView(
      view: BodyView.back,
      intensities: {Muscle.glutes: 0.3},
      selected: Muscle.glutes,
    )));
    expect(_state(t).lookOf(Muscle.glutes),
        MuscleMapView.targetLook(0.3, selected: true));
  });

  testWidgets('reduced motion applies highlights at once', (t) async {
    await t.pumpWidget(_host(const MuscleMapView(view: BodyView.front),
        disableAnimations: true));
    await t.pumpWidget(
      _host(
        const MuscleMapView(
          view: BodyView.front,
          intensities: {Muscle.quadriceps: 1},
        ),
        disableAnimations: true,
      ),
    );
    await t.pump();
    expect(_state(t).lookOf(Muscle.quadriceps), MuscleMapView.targetLook(1));
  });

  testWidgets('a tap resolves to the muscle under the finger', (t) async {
    final taps = <Muscle?>[];
    await t.pumpWidget(_host(MuscleMapView(
      view: BodyView.front,
      onMuscleTap: taps.add,
    )));

    final g = _atlas[BodyView.front];
    final fit = g.fit(_size);
    final origin = t.getTopLeft(find.byType(MuscleMapView));
    Offset toScreen(Offset p) => origin + fit.offset + p * fit.scale;

    // A point inside the left pectoral that nothing covers.
    final chest =
        g.parts.firstWhere((p) => p.id == 'pectoralis_major_l').path;
    final b = chest.getBounds();
    Offset? inside;
    for (var y = b.top; y <= b.bottom && inside == null; y += 3) {
      for (var x = b.left; x <= b.right; x += 3) {
        if (g.hitTest(Offset(x, y)) == Muscle.chest) {
          inside = Offset(x, y);
          break;
        }
      }
    }
    await t.tapAt(toScreen(inside!));
    await t.tapAt(origin + const Offset(2, 2));
    expect(taps, [Muscle.chest, null]);
  });
}

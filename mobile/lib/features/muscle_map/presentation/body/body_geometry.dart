import 'dart:typed_data';
import 'dart:ui';

import '../../domain/entities/muscle.dart';
import 'svg_path_parser.dart';

/// One tappable muscle shape: a region drawn on one view (both halves of a
/// paired muscle live in one [path]).
final class MuscleShape {
  const MuscleShape(this.muscle, this.view, this.path);

  final Muscle muscle;
  final BodyView view;
  final Path path;
}

/// The body map's vector geometry, authored in a 200 × 440 box with the
/// body's centre line at x = 100.
///
/// ARTWORK STATUS — these paths are hand-authored, stylised shapes that
/// follow the front silhouette of `assets/images/hub/dash-body.jpg`. They
/// are proper per-muscle vectors (no rectangles), but they are not traced
/// from anatomical artwork. Before release, have a designer replace:
///  * every BACK-view path (no back reference image exists in the repo),
///  * the deltoid heads and obliques (the reference shows no split),
///  * the adductors and front calves (small, approximate).
/// Swap a string below; ids, hit-testing and colouring need no change.
abstract final class BodyGeometry {
  static const Size viewBox = Size(200, 440);
  static const double _centre = 100;

  // Left half of the outline (viewer's left); mirrored for the right.
  static const _silhouetteHalf = 'M100,10 C88,10 80,19 80,33 C80,45 85,55 91,59 '
      'L90,70 C82,76 66,80 54,84 C42,88 36,98 36,112 C35,132 33,152 33,172 '
      'C32,188 30,202 28,216 C26,234 24,252 22,268 C20,282 20,294 25,300 '
      'C29,302 32,297 32,289 C33,276 36,262 40,248 C44,232 46,218 48,206 '
      'C51,186 54,160 56,132 L62,134 C63,160 65,186 68,210 '
      'C68,224 65,236 63,248 C60,272 60,302 64,332 C66,352 68,376 72,400 '
      'C74,412 72,422 68,430 L92,432 C91,422 90,412 90,400 '
      'C91,376 93,352 94,332 C96,304 98,280 100,262 Z';

  // Paired muscles: left half only, mirrored.
  static const Map<(Muscle, BodyView), String> _paired = {
    // ── Front ───────────────────────────────────────────────────────────
    (Muscle.chest, BodyView.front): 'M98,92 C88,89 74,91 64,99 '
        'C58,105 58,116 62,124 C68,132 80,136 92,134 C96,133 98,130 98,126 Z',
    (Muscle.deltAnterior, BodyView.front): 'M63,98 C58,91 50,89 45,94 '
        'C43,101 44,111 48,119 C53,113 57,106 63,100 Z',
    (Muscle.deltLateral, BodyView.front): 'M45,90 C39,94 36,103 37,116 '
        'C40,121 44,122 47,119 C43,111 42,101 45,94 Z',
    (Muscle.biceps, BodyView.front): 'M49,124 C43,134 41,150 41,166 '
        'C41,178 43,186 46,190 C50,180 54,166 55,150 C55,138 53,128 49,124 Z',
    (Muscle.forearms, BodyView.front): 'M44,198 C38,208 34,224 32,242 '
        'C31,254 32,263 34,268 C38,258 42,240 46,226 C48,214 48,204 44,198 Z',
    (Muscle.obliques, BodyView.front): 'M82,140 C76,137 69,135 65,138 '
        'C65,160 67,186 69,208 C73,214 78,220 84,226 C84,204 84,170 82,140 Z',
    (Muscle.adductors, BodyView.front): 'M89,262 C94,264 98,266 99,270 '
        'C98,284 96,298 93,308 C91,292 89,276 89,262 Z',
    (Muscle.quadriceps, BodyView.front): 'M67,252 C63,272 63,296 67,316 '
        'C71,328 78,332 86,328 C91,312 92,292 92,272 C88,262 79,255 67,252 Z',
    (Muscle.calves, BodyView.front): 'M67,352 C64,364 64,380 68,396 '
        'C70,401 73,401 75,396 C77,380 76,364 71,352 Z '
        'M86,352 C90,364 90,380 88,396 C86,400 84,398 84,392 '
        'C82,378 82,364 86,352 Z',
    // ── Back ────────────────────────────────────────────────────────────
    (Muscle.lats, BodyView.back): 'M62,104 C58,116 60,140 64,164 '
        'C68,186 76,204 86,214 C90,200 94,180 96,160 C94,150 86,142 76,134 '
        'C68,126 64,116 62,104 Z',
    (Muscle.upperBack, BodyView.back): 'M91,113 C82,103 71,99 63,101 '
        'C63,111 67,123 75,131 C83,137 92,141 98,143 L100,141 '
        'C98,131 96,121 91,113 Z',
    (Muscle.traps, BodyView.back): 'M100,62 C96,72 88,80 74,86 '
        'C66,88 60,90 57,94 C67,96 82,101 91,112 C96,120 98,130 100,140 Z',
    (Muscle.deltPosterior, BodyView.back): 'M57,95 C49,92 43,96 41,104 '
        'C41,112 43,118 47,121 C51,113 56,105 61,99 Z',
    (Muscle.deltLateral, BodyView.back): 'M45,90 C39,94 36,103 37,116 '
        'C40,121 44,122 47,119 C43,111 42,101 45,94 Z',
    (Muscle.triceps, BodyView.back): 'M47,123 C41,135 39,151 39,167 '
        'C39,179 41,187 45,191 C51,179 55,161 55,147 C55,137 51,129 47,123 Z',
    (Muscle.forearms, BodyView.back): 'M44,198 C38,208 34,224 32,242 '
        'C31,254 32,263 34,268 C38,258 42,240 46,226 C48,214 48,204 44,198 Z',
    (Muscle.glutes, BodyView.back): 'M99,242 C89,237 75,239 67,249 '
        'C63,261 65,275 73,283 C83,289 94,287 99,279 Z',
    (Muscle.hamstrings, BodyView.back): 'M67,290 C65,304 67,320 71,332 '
        'C77,336 85,336 89,330 C93,314 94,300 94,292 C86,294 75,294 67,290 Z',
    (Muscle.calves, BodyView.back): 'M68,344 C62,356 62,374 66,388 '
        'C70,394 76,394 80,388 C84,374 86,358 84,346 C80,340 72,340 68,344 Z',
  };

  // Single shapes on the centre line, drawn as authored.
  static const Map<(Muscle, BodyView), String> _centred = {
    (Muscle.upperAbs, BodyView.front):
        'M87,140 C93,137 107,137 113,140 L114,178 C105,181 95,181 86,178 Z',
    (Muscle.lowerAbs, BodyView.front): 'M86,183 C95,186 105,186 114,183 '
        'C114,202 111,222 106,240 C102,246 98,246 94,240 C89,222 86,202 86,183 Z',
    (Muscle.lowerBack, BodyView.back): 'M88,188 C94,185 106,185 112,188 '
        'C114,206 114,224 110,238 C104,242 96,242 90,238 C86,224 86,206 88,188 Z',
  };

  /// Paint order per view, bottom to top; hit-testing walks it backwards.
  static const Map<BodyView, List<Muscle>> _order = {
    BodyView.front: [
      Muscle.obliques,
      Muscle.upperAbs,
      Muscle.lowerAbs,
      Muscle.chest,
      Muscle.deltLateral,
      Muscle.deltAnterior,
      Muscle.biceps,
      Muscle.forearms,
      Muscle.quadriceps,
      Muscle.adductors,
      Muscle.calves,
    ],
    BodyView.back: [
      Muscle.lats,
      Muscle.upperBack,
      Muscle.lowerBack,
      Muscle.traps,
      Muscle.deltLateral,
      Muscle.deltPosterior,
      Muscle.triceps,
      Muscle.forearms,
      Muscle.glutes,
      Muscle.hamstrings,
      Muscle.calves,
    ],
  };

  static final Float64List _mirror = Float64List.fromList([
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    _centre * 2, 0, 0, 1,
  ]);

  static Path _withMirror(Path half) =>
      Path.from(half)..addPath(half.transform(_mirror), Offset.zero);

  static final Path silhouette = () {
    final half = parseSvgPath(_silhouetteHalf);
    return Path.combine(PathOperation.union, half, half.transform(_mirror));
  }();

  static final Map<BodyView, List<MuscleShape>> _shapes = {
    for (final view in BodyView.values)
      view: [
        for (final muscle in _order[view]!)
          MuscleShape(
            muscle,
            view,
            _paired.containsKey((muscle, view))
                ? _withMirror(parseSvgPath(_paired[(muscle, view)]!))
                : parseSvgPath(_centred[(muscle, view)]!),
          ),
      ],
  };

  /// Shapes for [view] in paint order.
  static List<MuscleShape> shapes(BodyView view) => _shapes[view]!;

  /// Topmost muscle under [point] (in view-box coordinates), or null.
  static Muscle? hitTest(BodyView view, Offset point) {
    for (final shape in shapes(view).reversed) {
      if (shape.path.contains(point)) return shape.muscle;
    }
    return null;
  }

  /// Fits the view box into [size], centred, keeping its aspect ratio.
  static ({double scale, Offset offset}) fit(Size size) {
    final scale = (size.width / viewBox.width) < (size.height / viewBox.height)
        ? size.width / viewBox.width
        : size.height / viewBox.height;
    return (
      scale: scale,
      offset: Offset(
        (size.width - viewBox.width * scale) / 2,
        (size.height - viewBox.height * scale) / 2,
      ),
    );
  }
}

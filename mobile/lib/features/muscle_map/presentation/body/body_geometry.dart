import 'dart:ui';

import 'package:flutter/services.dart' show AssetBundle;

import '../../domain/entities/muscle.dart';
import 'svg_path_parser.dart';

/// One vector shape from an anatomy asset.
final class AnatomyPart {
  const AnatomyPart({
    required this.id,
    required this.z,
    required this.path,
    this.muscle,
    this.isLine = false,
  });

  /// The upstream anatomical id (e.g. `pectoralis_major_l`). Stable.
  final String id;

  /// Upstream paint order. The art relies on it — a later shape covers an
  /// earlier one (the upper trapezius sits over the whole trapezius).
  final int z;
  final Path path;

  /// Body-map region this shape lights, or null for detail (tendons,
  /// hands, face, unlabelled shapes) that is outlined but never lit.
  final Muscle? muscle;

  /// Stroke-only line work: never filled, never hit-tested.
  final bool isLine;
}

/// The anatomy for one view, parsed from `assets/anatomy/body_<view>.svg`.
///
/// Asset contract (written by `tool/anatomy/build_anatomy_assets.py`):
///  * `<svg viewBox="0 0 W H">`
///  * `<path id="silhouette" fill-rule="evenodd" d="…"/>` — the body;
///  * `<g id="detail">` — outline-only paths;
///  * `<g id="muscles">` holding one `<g id="<Muscle.name>">` per region,
///    each with the anatomical `<path id=… data-z=… d=…/>` that form it.
///
/// The art is Ryan Graves' muscle anatomy (CC BY 4.0); see
/// `assets/anatomy/ATTRIBUTION.md`.
final class BodyGeometry {
  BodyGeometry._(this.view, this.viewBox, this.silhouette, this.parts)
      : muscles = {
          for (final p in parts)
            if (p.muscle != null) p.muscle!,
        };

  static const Map<BodyView, String> assetPaths = {
    BodyView.front: 'assets/anatomy/body_front.svg',
    BodyView.back: 'assets/anatomy/body_back.svg',
  };

  final BodyView view;
  final Size viewBox;
  final Path silhouette;

  /// Every shape, in paint order (lowest [AnatomyPart.z] first).
  final List<AnatomyPart> parts;

  /// Regions drawn in this view.
  final Set<Muscle> muscles;

  late final Map<Muscle, Path> _regionPaths = () {
    final out = <Muscle, Path>{};
    for (final p in parts) {
      final m = p.muscle;
      if (m == null) continue;
      (out[m] ??= Path()).addPath(p.path, Offset.zero);
    }
    return out;
  }();

  /// All shapes of [muscle] combined (for glow and tests); null when the
  /// region isn't drawn in this view.
  Path? regionPath(Muscle muscle) => _regionPaths[muscle];

  /// Anatomical ids that make up [muscle] in this view.
  List<String> partIds(Muscle muscle) =>
      [for (final p in parts) if (p.muscle == muscle) p.id];

  static final _tag = RegExp(r'<(/?)(g|path)\b([^>]*?)/?>', dotAll: true);
  static final _attr = RegExp(r'([\w:-]+)="([^"]*)"');

  /// Parses an asset. Throws [FormatException] on anything off-contract —
  /// an unknown region id, a missing silhouette, an unsupported command.
  static BodyGeometry parse(BodyView view, String svg) {
    final vb = RegExp(r'viewBox="([^"]+)"').firstMatch(svg)?.group(1);
    final nums = vb?.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
    if (nums == null || nums.length != 4) {
      throw const FormatException('Anatomy asset has no viewBox');
    }

    Path? silhouette;
    final parts = <AnatomyPart>[];
    final groups = <String>[];
    for (final m in _tag.allMatches(svg)) {
      final closing = m.group(1)!.isNotEmpty;
      final tag = m.group(2)!;
      final attrs = {
        for (final a in _attr.allMatches(m.group(3)!)) a.group(1)!: a.group(2)!,
      };
      if (tag == 'g') {
        if (closing) {
          if (groups.isNotEmpty) groups.removeLast();
        } else {
          groups.add(attrs['id'] ?? '');
        }
        continue;
      }
      final id = attrs['id'];
      final d = attrs['d'];
      if (id == null || d == null) {
        throw FormatException('Anatomy path without id or d in ${view.name}');
      }
      if (id == 'silhouette') {
        silhouette = parseSvgPath(d)..fillType = PathFillType.evenOdd;
        continue;
      }
      Muscle? muscle;
      final inMuscles = groups.length >= 2 && groups[groups.length - 2] == 'muscles';
      if (inMuscles) {
        final name = groups.last;
        muscle = Muscle.values.asNameMap()[name];
        if (muscle == null) {
          throw FormatException('Unknown muscle region "$name" in ${view.name}');
        }
      }
      parts.add(AnatomyPart(
        id: id,
        z: int.tryParse(attrs['data-z'] ?? '') ?? parts.length,
        path: parseSvgPath(d),
        muscle: muscle,
        isLine: attrs['data-kind'] == 'line',
      ));
    }
    if (silhouette == null) {
      throw FormatException('Anatomy asset ${view.name} has no silhouette');
    }
    parts.sort((a, b) => a.z.compareTo(b.z));
    return BodyGeometry._(view, Size(nums[2], nums[3]), silhouette, parts);
  }

  /// The muscle under [point] (view-box coordinates): the topmost filled
  /// shape decides, so a tap on a tendon over a muscle selects nothing.
  Muscle? hitTest(Offset point) {
    if (!silhouette.getBounds().contains(point)) return null;
    for (final p in parts.reversed) {
      if (p.isLine) continue;
      if (p.path.contains(point)) return p.muscle;
    }
    return null;
  }

  /// Fits the view box into [size], centred, keeping its aspect ratio.
  ({double scale, Offset offset}) fit(Size size) {
    final sx = size.width / viewBox.width;
    final sy = size.height / viewBox.height;
    final scale = sx < sy ? sx : sy;
    return (
      scale: scale,
      offset: Offset(
        (size.width - viewBox.width * scale) / 2,
        (size.height - viewBox.height * scale) / 2,
      ),
    );
  }
}

/// Front and back anatomy, loaded once.
final class BodyAtlas {
  BodyAtlas(this.views);

  final Map<BodyView, BodyGeometry> views;

  BodyGeometry operator [](BodyView view) => views[view]!;

  /// Loads and parses both assets from [bundle] (normally `rootBundle`).
  static Future<BodyAtlas> load(AssetBundle bundle) async {
    final entries = await Future.wait([
      for (final view in BodyView.values)
        bundle
            .loadString(BodyGeometry.assetPaths[view]!)
            .then((svg) => MapEntry(view, BodyGeometry.parse(view, svg))),
    ]);
    return BodyAtlas(Map.fromEntries(entries));
  }
}

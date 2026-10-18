import 'dart:ui';

/// Minimal SVG path-data parser (M L H V C S Q T A Z, absolute and
/// relative) — enough to draw the achievement glyph outlines without
/// adding an SVG package.
Path parseSvgPath(String data) {
  final tokens = _token
      .allMatches(data)
      .map((m) => m.group(0)!)
      .toList(growable: false);
  final path = Path();

  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0; // current point
  var startX = 0.0, startY = 0.0; // sub-path start
  double? cubicCx, cubicCy; // last cubic control point (for S)
  double? quadCx, quadCy; // last quadratic control point (for T)

  bool isCommand(String t) => _command.hasMatch(t);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      cmd = tokens[i++];
    }
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0;
    final oy = rel ? y : 0.0;
    var keepCubic = false;
    var keepQuad = false;

    switch (cmd.toUpperCase()) {
      case 'M':
        {
          x = ox + n();
          y = oy + n();
          path.moveTo(x, y);
          startX = x;
          startY = y;
          // Further pairs after a moveto are implicit linetos.
          cmd = rel ? 'l' : 'L';
        }
      case 'L':
        {
          x = ox + n();
          y = oy + n();
          path.lineTo(x, y);
        }
      case 'H':
        {
          x = ox + n();
          path.lineTo(x, y);
        }
      case 'V':
        {
          y = oy + n();
          path.lineTo(x, y);
        }
      case 'C':
        {
          final x1 = ox + n(), y1 = oy + n();
          final x2 = ox + n(), y2 = oy + n();
          x = ox + n();
          y = oy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          cubicCx = x2;
          cubicCy = y2;
          keepCubic = true;
        }
      case 'S':
        {
          final x1 = cubicCx == null ? x : 2 * x - cubicCx;
          final y1 = cubicCy == null ? y : 2 * y - cubicCy;
          final x2 = ox + n(), y2 = oy + n();
          x = ox + n();
          y = oy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          cubicCx = x2;
          cubicCy = y2;
          keepCubic = true;
        }
      case 'Q':
        {
          final x1 = ox + n(), y1 = oy + n();
          x = ox + n();
          y = oy + n();
          path.quadraticBezierTo(x1, y1, x, y);
          quadCx = x1;
          quadCy = y1;
          keepQuad = true;
        }
      case 'T':
        {
          final x1 = quadCx == null ? x : 2 * x - quadCx;
          final y1 = quadCy == null ? y : 2 * y - quadCy;
          x = ox + n();
          y = oy + n();
          path.quadraticBezierTo(x1, y1, x, y);
          quadCx = x1;
          quadCy = y1;
          keepQuad = true;
        }
      case 'A':
        {
          final rx = n(), ry = n(), rotation = n();
          final largeArc = n() != 0;
          final sweep = n() != 0;
          x = ox + n();
          y = oy + n();
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
        }
      case 'Z':
        {
          path.close();
          x = startX;
          y = startY;
          // A number straight after Z is malformed; skip it.
          if (i < tokens.length && !isCommand(tokens[i])) i++;
        }
      default:
        i++;
    }

    if (!keepCubic) {
      cubicCx = null;
      cubicCy = null;
    }
    if (!keepQuad) {
      quadCx = null;
      quadCy = null;
    }
  }
  return path;
}

final RegExp _token = RegExp(
  r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?',
);
final RegExp _command = RegExp(r'^[MmLlHhVvCcSsQqTtAaZz]$');

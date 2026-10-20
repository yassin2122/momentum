import 'dart:ui';

/// Parses the SVG path subset the anatomy assets use: absolute `M`, `L`,
/// `H`, `V`, `C`, `Q` and `Z`. Anything else (relative commands, arcs…)
/// throws, so an asset exported with unsupported commands fails loudly in
/// tests instead of drawing garbage.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  double next() {
    if (i >= tokens.length) throw FormatException('Path ends early: $d');
    final v = double.tryParse(tokens[i++]);
    if (v == null) throw FormatException('Expected a number in: $d');
    return v;
  }

  bool isNumber() => i < tokens.length && double.tryParse(tokens[i]) != null;

  // H and V need the current point, which Path doesn't expose.
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  String? command;
  while (i < tokens.length) {
    if (!isNumber()) command = tokens[i++];
    switch (command) {
      case 'M':
        x = startX = next();
        y = startY = next();
        path.moveTo(x, y);
        command = 'L'; // extra pairs after M are line-tos
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        {
          final x1 = next(), y1 = next(), x2 = next(), y2 = next();
          x = next();
          y = next();
          path.cubicTo(x1, y1, x2, y2, x, y);
        }
      case 'Q':
        {
          final x1 = next(), y1 = next();
          x = next();
          y = next();
          path.quadraticBezierTo(x1, y1, x, y);
        }
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unsupported path command "$command" in: $d');
    }
  }
  return path;
}

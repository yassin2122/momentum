import 'dart:ui';

/// Parses the small SVG path subset the body map is authored in:
/// absolute `M`, `L`, `C`, `Q` and `Z`. Anything else throws, so a typo in
/// a path string fails loudly in tests instead of drawing garbage.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MLCQZ]|-?\d*\.?\d+(?:e-?\d+)?', caseSensitive: false)
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

  String? command;
  while (i < tokens.length) {
    if (!isNumber()) command = tokens[i++];
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
        command = 'L'; // extra pairs after M are line-tos
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Q':
        path.quadraticBezierTo(next(), next(), next(), next());
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported path command "$command" in: $d');
    }
  }
  return path;
}

import '../../../../core/error/failure.dart';

/// Display helpers for the raw lowercase facet values stored in the
/// exercise library ("lower back", "olympic weightlifting", "e-z curl bar").
abstract final class ExerciseLabels {
  /// "lower back" → "Lower Back", "e-z curl bar" → "E-z Curl Bar".
  static String title(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'[\s_]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static const _difficultyOrder = ['beginner', 'intermediate', 'expert'];

  /// Beginner → Intermediate → Expert, then anything unexpected A–Z.
  static List<String> sortDifficulties(Iterable<String> values) {
    int rank(String v) {
      final i = _difficultyOrder.indexOf(v.toLowerCase());
      return i == -1 ? _difficultyOrder.length : i;
    }

    return values.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
  }

  /// First letter used for the A–Z section headers; digits and symbols
  /// are grouped under "#".
  static String sectionLetter(String name) {
    final t = name.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  static String errorMessage(Object error) =>
      error is Failure ? error.message : 'Something went wrong.';
}

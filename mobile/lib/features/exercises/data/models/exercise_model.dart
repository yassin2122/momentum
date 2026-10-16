import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/exercise_entity.dart';

/// Maps a raw row from [exercise_library_view] (as returned by
/// supabase_flutter's PostgREST client — a `Map<String, dynamic>` with
/// snake_case keys) to the domain entity. This is the only translation
/// boundary — nothing outside the data layer should parse raw rows.
///
/// Column → field mapping (all from exercise_library_view):
///   id                 → id
///   name               → name
///   slug               → slug
///   description        → description
///   exercise_type      → exerciseType
///   difficulty         → difficulty
///   mechanics          → mechanics
///   force              → force
///   is_custom          → isCustom
///   primary_muscle     → primaryMuscle  (text, from muscle_groups.name)
///   secondary_muscles  → secondaryMuscles (text[])
///   equipment          → equipment       (text[])
///   images             → images          (text[] of relative paths, resolved
///                                         against exerciseImageBaseUrl)
///   instructions       → instructions
final class ExerciseModel {
  const ExerciseModel._();

  static ExerciseEntity fromRow(Map<String, dynamic> row) {
    return ExerciseEntity(
      id: row['id'] as String,
      name: row['name'] as String,
      slug: row['slug'] as String?,
      description: row['description'] as String?,
      exerciseType: row['exercise_type'] as String? ?? '',
      difficulty: row['difficulty'] as String?,
      mechanics: row['mechanics'] as String?,
      force: row['force'] as String?,
      isCustom: row['is_custom'] as bool? ?? false,
      primaryMuscle: row['primary_muscle'] as String? ?? '',
      secondaryMuscles: _toStringList(row['secondary_muscles']),
      equipment: _toStringList(row['equipment']),
      images: _toStringList(row['images']).map(_imageUrl).toList(),
      instructions: row['instructions'] as String?,
    );
  }

  /// Relative paths get the image base URL; absolute URLs pass through.
  static String _imageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${AppConstants.exerciseImageBaseUrl}$path';
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return List<String>.from(value);
    return const [];
  }
}

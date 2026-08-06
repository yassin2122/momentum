/// Domain-level representation of an exercise. Used for both list
/// (summary) and detail contexts — `instructions` is simply absent
/// (null) when fetched as part of a list, since the list query never
/// requests that column.
final class ExerciseEntity {
  const ExerciseEntity({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.exerciseType,
    required this.images,
    this.slug,
    this.description,
    this.difficulty,
    this.mechanics,
    this.force,
    this.instructions,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String primaryMuscle;
  final List<String> secondaryMuscles;

  /// One or more pieces of equipment, e.g. ['Barbell', 'Rack'].
  /// Empty list means bodyweight.
  final List<String> equipment;
  final String exerciseType;

  /// Ordered image URLs from exercise_images, used by cached_network_image.
  final List<String> images;

  final String? slug;
  final String? description;
  final String? difficulty;
  final String? mechanics;
  final String? force;
  final String? instructions;
  final bool isCustom;

  /// Returns the first image URL or null (for thumbnail display).
  String? get thumbnailUrl => images.isNotEmpty ? images.first : null;

  /// Returns a displayable equipment string, e.g. "Barbell" or "Bodyweight".
  String get equipmentLabel {
    if (equipment.isEmpty) return 'Bodyweight';
    return equipment.first;
  }
}

/// One page of exercise results plus enough state to fetch the next page.
final class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<ExerciseEntity> items;
  final bool hasMore;

  /// Offset to request for the next page. See the repository doc comment
  /// for why this is offset-based rather than the cursor design in
  /// API_CONTRACT.md — a deliberate adaptation for the direct-Supabase
  /// implementation used this sprint.
  final int nextOffset;
}

/// Distinct facet values actually present in the library — powers the
/// filter UI without hardcoding a taxonomy, per API_CONTRACT.md.
final class ExerciseFilterOptions {
  const ExerciseFilterOptions({
    required this.primaryMuscles,
    required this.equipment,
    required this.exerciseTypes,
    required this.difficulties,
  });

  final List<String> primaryMuscles;
  final List<String> equipment;
  final List<String> exerciseTypes;
  final List<String> difficulties;

  static const empty = ExerciseFilterOptions(
    primaryMuscles: [],
    equipment: [],
    exerciseTypes: [],
    difficulties: [],
  );
}

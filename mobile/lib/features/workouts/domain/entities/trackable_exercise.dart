import '../../../../core/constants/app_constants.dart';
import 'workout_enums.dart';

/// The slice of an `exercises` row the workout logger needs.
final class TrackableExercise {
  const TrackableExercise({
    required this.id,
    required this.name,
    required this.trackingType,
    this.bwFactor = 0,
    this.equipment,
    this.isCustom = false,
    this.slug,
    this.imagePath,
    this.primaryMuscle,
  });

  final String id;
  final String name;
  final TrackingType trackingType;

  /// Share of bodyweight lifted (bodyweight types only), e.g. 1.0 for a
  /// pull-up, ~0.65 for a push-up.
  final double bwFactor;
  final String? equipment;
  final bool isCustom;

  /// Library slug (stable id from the exercise DB), null for custom ones.
  final String? slug;

  /// First entry of `exercises.images` — a path relative to
  /// [AppConstants.exerciseImageBaseUrl], or an absolute URL.
  final String? imagePath;

  /// Library muscle-group name of the primary target, when fetched.
  final String? primaryMuscle;

  /// Thumbnail URL, or null when the exercise has no photo.
  String? get imageUrl {
    final p = imagePath;
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '${AppConstants.exerciseImageBaseUrl}$p';
  }

  /// Reads a row from `exercises`. Optional columns (`slug`, `images`) and
  /// the `exercise_muscle_groups(is_primary, muscle_groups(name))` embed
  /// are used when present; [toJson]'s own keys round-trip too.
  factory TrackableExercise.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    return TrackableExercise(
      id: json['id'] as String,
      name: json['name'] as String,
      trackingType: TrackingType.fromDb(json['tracking_type'] as String?),
      bwFactor: (json['bw_factor'] as num?)?.toDouble() ?? 0,
      equipment: json['equipment'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      slug: json['slug'] as String?,
      imagePath: json['image_path'] as String? ??
          (images is List && images.isNotEmpty ? images.first as String? : null),
      primaryMuscle:
          json['primary_muscle'] as String? ?? _primaryFromEmbed(json),
    );
  }

  static String? _primaryFromEmbed(Map<String, dynamic> json) {
    final links = json['exercise_muscle_groups'];
    if (links is! List) return null;
    final names = <String>[
      for (final l in links)
        if (l is Map && l['is_primary'] == true && l['muscle_groups'] is Map)
          if ((l['muscle_groups'] as Map)['name'] case final String name) name,
    ]..sort();
    return names.isEmpty ? null : names.first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracking_type': trackingType.dbValue,
        'bw_factor': bwFactor,
        'equipment': equipment,
        'is_custom': isCustom,
        if (slug != null) 'slug': slug,
        if (imagePath != null) 'image_path': imagePath,
        if (primaryMuscle != null) 'primary_muscle': primaryMuscle,
      };
}

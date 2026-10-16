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
  });

  final String id;
  final String name;
  final TrackingType trackingType;

  /// Share of bodyweight lifted (bodyweight types only), e.g. 1.0 for a
  /// pull-up, ~0.65 for a push-up.
  final double bwFactor;
  final String? equipment;
  final bool isCustom;

  factory TrackableExercise.fromJson(Map<String, dynamic> json) =>
      TrackableExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        trackingType: TrackingType.fromDb(json['tracking_type'] as String?),
        bwFactor: (json['bw_factor'] as num?)?.toDouble() ?? 0,
        equipment: json['equipment'] as String?,
        isCustom: json['is_custom'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracking_type': trackingType.dbValue,
        'bw_factor': bwFactor,
        'equipment': equipment,
        'is_custom': isCustom,
      };
}

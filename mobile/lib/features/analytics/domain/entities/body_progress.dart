/// A tracked body metric. [column] is the `body_metrics_log` column.
enum BodyMeasure {
  weight('weight_kg', 'Bodyweight', 'kg'),
  bodyFat('body_fat_pct', 'Body fat', '%'),
  waist('waist_cm', 'Waist', 'cm'),
  chest('chest_cm', 'Chest', 'cm'),
  hips('hips_cm', 'Hips', 'cm'),
  arm('arm_cm', 'Arm', 'cm'),
  thigh('thigh_cm', 'Thigh', 'cm'),
  calf('calf_cm', 'Calf', 'cm'),
  neck('neck_cm', 'Neck', 'cm');

  const BodyMeasure(this.column, this.label, this.unit);

  final String column;
  final String label;

  /// Canonical unit as stored. Weight is shown in the user's preferred
  /// unit; lengths stay in cm.
  final String unit;

  /// Inclusive plausible range, matching `body_metrics_plausible` in the
  /// migration — in the canonical [unit].
  (double, double) get limits => switch (this) {
        BodyMeasure.weight => (20, 400),
        BodyMeasure.bodyFat => (2, 70),
        BodyMeasure.neck => (15, 80),
        BodyMeasure.chest => (40, 250),
        BodyMeasure.waist => (30, 250),
        BodyMeasure.hips => (40, 250),
        BodyMeasure.arm => (10, 80),
        BodyMeasure.thigh => (20, 120),
        BodyMeasure.calf => (15, 80),
      };

  bool get isLength => unit == 'cm';
}

/// One `body_metrics_log` row.
final class BodyEntry {
  const BodyEntry({
    required this.id,
    required this.loggedOn,
    required this.values,
    required this.createdAt,
    this.note,
  });

  final String id;

  /// Local calendar date the measurement is for.
  final DateTime loggedOn;

  /// Only the measures filled in this entry.
  final Map<BodyMeasure, double> values;
  final String? note;
  final DateTime createdAt;

  double? operator [](BodyMeasure m) => values[m];
}

/// The athlete's optional bodyweight goal (`body_goals`).
final class BodyGoal {
  const BodyGoal({
    required this.targetWeightKg,
    required this.createdAt,
    this.startWeightKg,
    this.targetDate,
  });

  final double targetWeightKg;

  /// Bodyweight when the goal was set (fixed origin for progress).
  final double? startWeightKg;
  final DateTime? targetDate;
  final DateTime createdAt;
}

enum PhotoPose {
  front('front', 'Front'),
  side('side', 'Side'),
  back('back', 'Back'),
  other('other', 'Other');

  const PhotoPose(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PhotoPose fromDb(String? v) =>
      PhotoPose.values.firstWhere((p) => p.dbValue == v, orElse: () => other);
}

/// A private progress photo (`progress_photos` + the private bucket).
final class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.storagePath,
    required this.pose,
    required this.takenOn,
    required this.createdAt,
    this.note,
    this.url,
  });

  final String id;
  final String storagePath;
  final PhotoPose pose;
  final DateTime takenOn;
  final String? note;
  final DateTime createdAt;

  /// Short-lived signed URL; null if it couldn't be created.
  final String? url;
}

/// Everything the Body progress screen shows.
final class BodyProgressData {
  const BodyProgressData({
    required this.entries,
    required this.goal,
    required this.photos,
  });

  /// Newest first.
  final List<BodyEntry> entries;
  final BodyGoal? goal;

  /// Newest first.
  final List<ProgressPhoto> photos;

  bool get isEmpty => entries.isEmpty && photos.isEmpty && goal == null;
}

/// A new measurement to save. Values are canonical (kg, %, cm).
final class NewBodyEntry {
  const NewBodyEntry({
    required this.loggedOn,
    required this.values,
    this.note,
  });

  final DateTime loggedOn;
  final Map<BodyMeasure, double> values;
  final String? note;
}

/// Domain types for the CONNECT pillar (coaching). Field sets mirror the
/// live schema (migrations 28–32) one-to-one; see `SCHEMA.md` §2 / §4.
///
/// Lifecycle changes (choose / accept / end / assign) are RPC-only — these
/// types are read models, never written back as whole rows.
library;

/// `coaching_status` enum.
enum CoachingStatus {
  pending,
  active,
  ended,
  declined;

  static CoachingStatus fromDb(String value) =>
      CoachingStatus.values.firstWhere((s) => s.name == value);
}

/// `assignment_status` enum.
enum AssignmentStatus {
  assigned('assigned'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const AssignmentStatus(this.dbValue);
  final String dbValue;

  static AssignmentStatus fromDb(String value) =>
      AssignmentStatus.values.firstWhere((s) => s.dbValue == value);
}

/// One row of the `get_coach_directory` RPC (approved coaches only).
final class CoachDirectoryEntry {
  const CoachDirectoryEntry({
    required this.coachId,
    required this.specialties,
    required this.acceptingAthletes,
    required this.athleteCount,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.headline,
    this.experienceYears,
  });

  final String coachId;
  final List<String> specialties;
  final bool acceptingAthletes;
  final int athleteCount;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? headline;
  final int? experienceYears;
}

/// `coaching_relationships` row. RLS returns only rows where the caller is
/// the athlete or the coach.
final class CoachingRelationship {
  const CoachingRelationship({
    required this.id,
    required this.athleteId,
    required this.coachId,
    required this.status,
    required this.requestedAt,
    this.planId,
    this.startedAt,
    this.endedAt,
    this.endedBy,
  });

  final String id;
  final String athleteId;
  final String coachId;
  final CoachingStatus status;
  final DateTime requestedAt;
  final String? planId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endedBy;
}

/// `coaching_permissions` row — the athlete's consent scopes.
final class CoachingPermissions {
  const CoachingPermissions({
    required this.relationshipId,
    required this.shareWorkouts,
    required this.sharePrs,
    required this.shareSkillProgress,
    required this.shareBodyMetrics,
    required this.updatedAt,
  });

  final String relationshipId;
  final bool shareWorkouts;
  final bool sharePrs;
  final bool shareSkillProgress;
  final bool shareBodyMetrics;
  final DateTime updatedAt;
}

/// `coaching_feedback` row (append-only; either party may write while the
/// relationship is active).
final class CoachingFeedback {
  const CoachingFeedback({
    required this.id,
    required this.relationshipId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.workoutLogId,
    this.skillId,
  });

  final String id;
  final String relationshipId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? workoutLogId;
  final String? skillId;
}

/// `coaching_goals` row. `status` is a text column checked to
/// 'active' | 'achieved' | 'dropped'.
final class CoachingGoal {
  const CoachingGoal({
    required this.id,
    required this.relationshipId,
    required this.title,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.targetDate,
  });

  final String id;
  final String relationshipId;
  final String title;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final DateTime? targetDate;
}

/// `program_assignments` row.
final class ProgramAssignment {
  const ProgramAssignment({
    required this.id,
    required this.relationshipId,
    required this.programId,
    required this.assignedBy,
    required this.startDate,
    required this.status,
    required this.createdAt,
    this.instructions,
    this.enrollmentId,
    this.completedAt,
  });

  final String id;
  final String relationshipId;
  final String programId;
  final String assignedBy;
  final DateTime startDate;
  final AssignmentStatus status;
  final DateTime createdAt;
  final String? instructions;
  final String? enrollmentId;
  final DateTime? completedAt;
}

/// `get_athlete_body_profile` result — only returned to an active Captain
/// with the `body` scope on.
final class AthleteBodyProfile {
  const AthleteBodyProfile({
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.gender,
  });

  final int? ageYears;
  final double? heightCm;
  final double? weightKg;

  /// `gender_type`: 'male' | 'female' | 'unspecified'.
  final String? gender;
}

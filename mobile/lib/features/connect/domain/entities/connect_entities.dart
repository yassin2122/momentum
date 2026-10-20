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

/// One row of the `get_coach_directory` RPC (approved, listed coaches), or
/// of `get_coach_card` (one approved coach, listed or not). Only the card
/// fills [bio], [approach] and [certifications].
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
    this.bio,
    this.approach,
    this.certifications = const [],
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
  final String? bio;
  final String? approach;
  final List<String> certifications;
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

// ---------------------------------------------------------------------------
// Captain Hub (migration 20261020200000)
// ---------------------------------------------------------------------------

/// `coach_status` enum.
enum CoachStatus {
  pending,
  approved,
  suspended;

  static CoachStatus fromDb(String value) =>
      CoachStatus.values.firstWhere((s) => s.name == value);
}

/// The signed-in Captain's own `coach_profiles` row, as returned inside
/// `get_captain_hub`. Also the input to [ConnectRepository.saveCoachProfile].
final class CaptainProfileDraft {
  const CaptainProfileDraft({
    this.headline,
    this.bio,
    this.approach,
    this.specialties = const [],
    this.certifications = const [],
    this.experienceYears,
    this.maxAthletes,
    this.acceptingAthletes = true,
    this.isListed = true,
  });

  final String? headline;
  final String? bio;
  final String? approach;
  final List<String> specialties;
  final List<String> certifications;
  final int? experienceYears;
  final int? maxAthletes;
  final bool acceptingAthletes;
  final bool isListed;

  /// Out of 4: headline, bio, at least one specialty, experience.
  int get completedFields => [
        headline?.isNotEmpty ?? false,
        bio?.isNotEmpty ?? false,
        specialties.isNotEmpty,
        experienceYears != null,
      ].where((done) => done).length;
}

/// A pending coaching request addressed to the Captain.
final class HubRequest {
  const HubRequest({
    required this.relationshipId,
    required this.athleteId,
    required this.requestedAt,
    this.displayName,
    this.username,
    this.avatarUrl,
  });

  final String relationshipId;
  final String athleteId;
  final DateTime requestedAt;
  final String? displayName;
  final String? username;
  final String? avatarUrl;

  String get name => displayName ?? username ?? 'Athlete';
}

/// An athlete the Captain actively coaches. [lastWorkoutAt] and
/// [workoutsLast7Days] are null when the athlete doesn't share workouts.
final class HubClient {
  const HubClient({
    required this.relationshipId,
    required this.athleteId,
    required this.startedAt,
    required this.fromInvite,
    required this.sharesWorkouts,
    required this.openAssignments,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.lastWorkoutAt,
    this.workoutsLast7Days,
  });

  final String relationshipId;
  final String athleteId;
  final DateTime startedAt;
  final bool fromInvite;
  final bool sharesWorkouts;
  final int openAssignments;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime? lastWorkoutAt;
  final int? workoutsLast7Days;

  String get name => displayName ?? username ?? 'Athlete';
}

/// An open (unused, unexpired, unrevoked) invite. The full code is never
/// stored — only its last 4 characters, as [codeHint].
final class HubInvite {
  const HubInvite({
    required this.id,
    required this.codeHint,
    required this.expiresAt,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String codeHint;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? note;
}

/// Everything the Captain Hub screen shows (`get_captain_hub`).
final class CaptainHub {
  const CaptainHub({
    required this.status,
    required this.profile,
    required this.requests,
    required this.clients,
    required this.invitations,
    required this.invitesAccepted,
  });

  final CoachStatus status;
  final CaptainProfileDraft profile;

  /// Oldest first.
  final List<HubRequest> requests;

  /// Newest coaching relationship first.
  final List<HubClient> clients;

  /// Newest first.
  final List<HubInvite> invitations;
  final int invitesAccepted;

  bool get isApproved => status == CoachStatus.approved;

  HubClient? clientByRelationship(String relationshipId) {
    for (final c in clients) {
      if (c.relationshipId == relationshipId) return c;
    }
    return null;
  }
}

/// Returned once by `create_coaching_invitation` — the only time the full
/// code exists outside the athlete's hands.
final class CreatedInvite {
  const CreatedInvite({
    required this.invitationId,
    required this.code,
    required this.expiresAt,
  });

  final String invitationId;
  final String code;
  final DateTime expiresAt;
}

/// `preview_coaching_invitation` — who sent a code, before accepting.
final class InvitePreview {
  const InvitePreview({
    required this.coachId,
    required this.specialties,
    required this.expiresAt,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.headline,
    this.experienceYears,
  });

  final String coachId;
  final List<String> specialties;
  final DateTime expiresAt;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? headline;
  final int? experienceYears;

  String get name => displayName ?? username ?? 'Coach';
}

/// One completed workout as summarized by `get_client_workouts`.
final class ClientWorkout {
  const ClientWorkout({
    required this.workoutLogId,
    required this.startedAt,
    required this.exerciseCount,
    required this.workingSets,
    required this.volumeKg,
    required this.exerciseNames,
    this.completedAt,
    this.durationSeconds,
  });

  final String workoutLogId;
  final DateTime startedAt;
  final int exerciseCount;
  final int workingSets;
  final double volumeKg;
  final List<String> exerciseNames;
  final DateTime? completedAt;
  final int? durationSeconds;
}

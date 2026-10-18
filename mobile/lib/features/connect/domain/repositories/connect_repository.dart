import '../../../../core/error/result.dart';
import '../entities/connect_entities.dart';

/// Contract for the CONNECT pillar. Reads go through RLS; every lifecycle
/// change goes through a `security definer` RPC — there is deliberately no
/// method that writes `coaching_relationships` or `program_assignments`
/// directly, and none that writes athlete logs as a coach.
abstract interface class ConnectRepository {
  // ---- Reads ----

  /// `get_coach_directory(p_specialty, p_limit)` — approved coaches only.
  Future<Result<List<CoachDirectoryEntry>>> getCoachDirectory({
    String? specialty,
    int? limit,
  });

  /// Every relationship the caller is part of (as athlete or coach),
  /// newest request first.
  Future<Result<List<CoachingRelationship>>> getMyRelationships();

  /// Consent flags for one relationship, or `null` if not visible.
  Future<Result<CoachingPermissions?>> getPermissions(String relationshipId);

  /// Feedback thread for one relationship, newest first.
  Future<Result<List<CoachingFeedback>>> getFeedback(String relationshipId);

  Future<Result<List<CoachingGoal>>> getGoals(String relationshipId);

  Future<Result<List<ProgramAssignment>>> getAssignments(String relationshipId);

  /// Captain-only, gated by `coach_can_view(athlete, 'body')`. Returns
  /// `null` when the scope is off or the caller is not the active Captain.
  Future<Result<AthleteBodyProfile?>> getAthleteBodyProfile(String athleteId);

  // ---- Writes allowed by RLS ----

  /// Athlete-only (RLS). Only the non-null flags are changed. Fails if the
  /// update touched no row (caller is not the athlete).
  Future<Result<void>> updatePermissions(
    String relationshipId, {
    bool? shareWorkouts,
    bool? sharePrs,
    bool? shareSkillProgress,
    bool? shareBodyMetrics,
  });

  /// Inserts into `coaching_feedback`. [authorId] must be the signed-in
  /// user's id (RLS checks `author_id = auth.uid()`); it's passed in so this
  /// layer doesn't touch the auth API (see CLAUDE.md, Supabase access).
  Future<Result<CoachingFeedback>> sendFeedback({
    required String relationshipId,
    required String authorId,
    required String body,
    String? workoutLogId,
    String? skillId,
  });

  // ---- RPC-only lifecycle ----

  /// `choose_captain` — returns the new relationship id. Omitted flags fall
  /// back to the database defaults (workouts/prs/progress on, body off).
  Future<Result<String>> chooseCaptain({
    required String coachId,
    String? planId,
    bool? shareWorkouts,
    bool? sharePrs,
    bool? shareSkillProgress,
    bool? shareBodyMetrics,
  });

  /// Coach-only: `respond_to_coaching_request`.
  Future<Result<void>> respondToRequest(String relationshipId,
      {required bool accept});

  /// Either party: `end_coaching`.
  Future<Result<void>> endCoaching(String relationshipId);

  /// Coach-only: `assign_program` — returns the new assignment id.
  Future<Result<String>> assignProgram({
    required String relationshipId,
    required String programId,
    DateTime? startDate,
    String? instructions,
  });

  /// Athlete: `start_assigned_program` — returns the enrollment id.
  Future<Result<String>> startAssignedProgram(String assignmentId);

  /// Athlete, or the coach while active: `complete_assignment`.
  Future<Result<void>> completeAssignment(String assignmentId);
}

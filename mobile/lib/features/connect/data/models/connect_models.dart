import '../../domain/entities/connect_entities.dart';

/// Row → entity mappers for the CONNECT tables/RPCs. Raw PostgREST rows are
/// `Map<String, dynamic>` with snake_case keys; nothing outside the data
/// layer should parse them.
final class ConnectModels {
  const ConnectModels._();

  static CoachDirectoryEntry directoryEntry(Map<String, dynamic> row) =>
      CoachDirectoryEntry(
        coachId: row['coach_id'] as String,
        specialties: _strings(row['specialties']),
        acceptingAthletes: row['accepting_athletes'] as bool? ?? false,
        athleteCount: (row['athlete_count'] as num?)?.toInt() ?? 0,
        username: row['username'] as String?,
        displayName: row['display_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        headline: row['headline'] as String?,
        experienceYears: (row['experience_years'] as num?)?.toInt(),
        bio: row['bio'] as String?,
        approach: row['approach'] as String?,
        certifications: _strings(row['certifications']),
      );

  static CoachingRelationship relationship(Map<String, dynamic> row) =>
      CoachingRelationship(
        id: row['id'] as String,
        athleteId: row['athlete_id'] as String,
        coachId: row['coach_id'] as String,
        status: CoachingStatus.fromDb(row['status'] as String),
        requestedAt: DateTime.parse(row['requested_at'] as String),
        planId: row['plan_id'] as String?,
        startedAt: _date(row['started_at']),
        endedAt: _date(row['ended_at']),
        endedBy: row['ended_by'] as String?,
      );

  static CoachingPermissions permissions(Map<String, dynamic> row) =>
      CoachingPermissions(
        relationshipId: row['relationship_id'] as String,
        shareWorkouts: row['share_workouts'] as bool,
        sharePrs: row['share_prs'] as bool,
        shareSkillProgress: row['share_skill_progress'] as bool,
        shareBodyMetrics: row['share_body_metrics'] as bool,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  static CoachingFeedback feedback(Map<String, dynamic> row) =>
      CoachingFeedback(
        id: row['id'] as String,
        relationshipId: row['relationship_id'] as String,
        authorId: row['author_id'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        workoutLogId: row['workout_log_id'] as String?,
        skillId: row['skill_id'] as String?,
      );

  static CoachingGoal goal(Map<String, dynamic> row) => CoachingGoal(
        id: row['id'] as String,
        relationshipId: row['relationship_id'] as String,
        title: row['title'] as String,
        status: row['status'] as String,
        createdBy: row['created_by'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        description: row['description'] as String?,
        targetDate: _date(row['target_date']),
      );

  static ProgramAssignment assignment(Map<String, dynamic> row) =>
      ProgramAssignment(
        id: row['id'] as String,
        relationshipId: row['relationship_id'] as String,
        programId: row['program_id'] as String,
        assignedBy: row['assigned_by'] as String,
        startDate: DateTime.parse(row['start_date'] as String),
        status: AssignmentStatus.fromDb(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        instructions: row['instructions'] as String?,
        enrollmentId: row['enrollment_id'] as String?,
        completedAt: _date(row['completed_at']),
      );

  static AthleteBodyProfile bodyProfile(Map<String, dynamic> row) =>
      AthleteBodyProfile(
        ageYears: (row['age_years'] as num?)?.toInt(),
        heightCm: (row['height_cm'] as num?)?.toDouble(),
        weightKg: (row['weight_kg'] as num?)?.toDouble(),
        gender: row['gender'] as String?,
      );

  // ---- Captain Hub ----

  /// `get_captain_hub()` jsonb → [CaptainHub].
  static CaptainHub captainHub(Map<String, dynamic> json) {
    final p = Map<String, dynamic>.from(json['profile'] as Map);
    return CaptainHub(
      status: CoachStatus.fromDb(p['status'] as String),
      profile: CaptainProfileDraft(
        headline: p['headline'] as String?,
        bio: p['bio'] as String?,
        approach: p['approach'] as String?,
        specialties: _strings(p['specialties']),
        certifications: _strings(p['certifications']),
        experienceYears: (p['experience_years'] as num?)?.toInt(),
        maxAthletes: (p['max_athletes'] as num?)?.toInt(),
        acceptingAthletes: p['accepting_athletes'] as bool? ?? true,
        isListed: p['is_listed'] as bool? ?? true,
      ),
      requests: _maps(json['requests'])
          .map((r) => HubRequest(
                relationshipId: r['relationship_id'] as String,
                athleteId: r['athlete_id'] as String,
                requestedAt: DateTime.parse(r['requested_at'] as String),
                displayName: r['display_name'] as String?,
                username: r['username'] as String?,
                avatarUrl: r['avatar_url'] as String?,
              ))
          .toList(),
      clients: _maps(json['clients'])
          .map((r) => HubClient(
                relationshipId: r['relationship_id'] as String,
                athleteId: r['athlete_id'] as String,
                startedAt: DateTime.parse(r['started_at'] as String),
                fromInvite: r['source'] == 'invite',
                sharesWorkouts: r['share_workouts'] as bool? ?? false,
                openAssignments: (r['open_assignments'] as num?)?.toInt() ?? 0,
                displayName: r['display_name'] as String?,
                username: r['username'] as String?,
                avatarUrl: r['avatar_url'] as String?,
                lastWorkoutAt: _date(r['last_workout_at']),
                workoutsLast7Days: (r['workouts_last_7_days'] as num?)?.toInt(),
              ))
          .toList(),
      invitations: _maps(json['invitations'])
          .map((r) => HubInvite(
                id: r['id'] as String,
                codeHint: r['code_hint'] as String,
                expiresAt: DateTime.parse(r['expires_at'] as String),
                createdAt: DateTime.parse(r['created_at'] as String),
                note: r['note'] as String?,
              ))
          .toList(),
      invitesAccepted: (json['invites_accepted'] as num?)?.toInt() ?? 0,
    );
  }

  static CreatedInvite createdInvite(Map<String, dynamic> row) => CreatedInvite(
        invitationId: row['invitation_id'] as String,
        code: row['code'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );

  static InvitePreview invitePreview(Map<String, dynamic> row) => InvitePreview(
        coachId: row['coach_id'] as String,
        specialties: _strings(row['specialties']),
        expiresAt: DateTime.parse(row['expires_at'] as String),
        username: row['username'] as String?,
        displayName: row['display_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        headline: row['headline'] as String?,
        experienceYears: (row['experience_years'] as num?)?.toInt(),
      );

  static ClientWorkout clientWorkout(Map<String, dynamic> row) => ClientWorkout(
        workoutLogId: row['workout_log_id'] as String,
        startedAt: DateTime.parse(row['started_at'] as String),
        exerciseCount: (row['exercise_count'] as num?)?.toInt() ?? 0,
        workingSets: (row['working_sets'] as num?)?.toInt() ?? 0,
        volumeKg: (row['volume_kg'] as num?)?.toDouble() ?? 0,
        exerciseNames: _strings(row['exercise_names']),
        completedAt: _date(row['completed_at']),
        durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
      );

  /// [CaptainProfileDraft] → `coach_profiles` columns (never `status`).
  static Map<String, dynamic> coachProfileColumns(CaptainProfileDraft d) => {
        'headline': _blankToNull(d.headline),
        'bio': _blankToNull(d.bio),
        'approach': _blankToNull(d.approach),
        'specialties': d.specialties,
        'certifications': d.certifications,
        'experience_years': d.experienceYears,
        'max_athletes': d.maxAthletes,
        'accepting_athletes': d.acceptingAthletes,
        'is_listed': d.isListed,
      };

  static String? _blankToNull(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? [for (final m in value) Map<String, dynamic>.from(m as Map)]
      : const [];

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static List<String> _strings(dynamic value) =>
      value is List ? List<String>.from(value) : const [];
}

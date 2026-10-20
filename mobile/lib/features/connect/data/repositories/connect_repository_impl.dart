import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/connect_entities.dart';
import '../../domain/repositories/connect_repository.dart';
import '../datasources/connect_remote_datasource.dart';
import '../models/connect_models.dart';

/// Concrete [ConnectRepository]. RPC errors raised by the database
/// ("Coach is at capacity", "Not your active athlete", …) come through as
/// [ServerFailure] with the database message.
class ConnectRepositoryImpl implements ConnectRepository {
  const ConnectRepositoryImpl(this._remote);

  final ConnectRemoteDataSource _remote;

  // ---- Reads ----

  @override
  Future<Result<List<CoachDirectoryEntry>>> getCoachDirectory({
    String? specialty,
    int? limit,
  }) =>
      _run(() async => (await _remote.fetchCoachDirectory(
              specialty: specialty, limit: limit))
          .map(ConnectModels.directoryEntry)
          .toList());

  @override
  Future<Result<List<CoachingRelationship>>> getMyRelationships() =>
      _run(() async => (await _remote.fetchRelationships())
          .map(ConnectModels.relationship)
          .toList());

  @override
  Future<Result<CoachingPermissions?>> getPermissions(String relationshipId) =>
      _run(() async {
        final row = await _remote.fetchPermissions(relationshipId);
        return row == null ? null : ConnectModels.permissions(row);
      });

  @override
  Future<Result<List<CoachingFeedback>>> getFeedback(String relationshipId) =>
      _run(() async => (await _remote.fetchFeedback(relationshipId))
          .map(ConnectModels.feedback)
          .toList());

  @override
  Future<Result<List<CoachingGoal>>> getGoals(String relationshipId) =>
      _run(() async => (await _remote.fetchGoals(relationshipId))
          .map(ConnectModels.goal)
          .toList());

  @override
  Future<Result<List<ProgramAssignment>>> getAssignments(
          String relationshipId) =>
      _run(() async => (await _remote.fetchAssignments(relationshipId))
          .map(ConnectModels.assignment)
          .toList());

  @override
  Future<Result<AthleteBodyProfile?>> getAthleteBodyProfile(String athleteId) =>
      _run(() async {
        final row = await _remote.fetchAthleteBodyProfile(athleteId);
        return row == null ? null : ConnectModels.bodyProfile(row);
      });

  @override
  Future<Result<CoachDirectoryEntry?>> getCoachCard(String coachId) =>
      _run(() async {
        final row = await _remote.fetchCoachCard(coachId);
        return row == null ? null : ConnectModels.directoryEntry(row);
      });

  @override
  Future<Result<CaptainHub?>> getCaptainHub() => _run(() async {
        final json = await _remote.fetchCaptainHub();
        return json == null ? null : ConnectModels.captainHub(json);
      });

  @override
  Future<Result<List<ClientWorkout>>> getClientWorkouts(String athleteId,
          {int? limit}) =>
      _run(() async =>
          (await _remote.fetchClientWorkouts(athleteId, limit: limit))
              .map(ConnectModels.clientWorkout)
              .toList());

  // ---- Writes allowed by RLS ----

  @override
  Future<Result<void>> saveCoachProfile({
    required String userId,
    required CaptainProfileDraft draft,
    required bool isNew,
  }) {
    final columns = ConnectModels.coachProfileColumns(draft);
    return _run(() => isNew
        ? _remote.insertCoachProfile(userId, columns)
        : _remote.updateCoachProfile(userId, columns));
  }

  @override
  Future<Result<void>> updatePermissions(
    String relationshipId, {
    bool? shareWorkouts,
    bool? sharePrs,
    bool? shareSkillProgress,
    bool? shareBodyMetrics,
  }) async {
    final changes = <String, bool>{
      if (shareWorkouts != null) 'share_workouts': shareWorkouts,
      if (sharePrs != null) 'share_prs': sharePrs,
      if (shareSkillProgress != null)
        'share_skill_progress': shareSkillProgress,
      if (shareBodyMetrics != null) 'share_body_metrics': shareBodyMetrics,
    };
    if (changes.isEmpty) return const Result.success(null);

    final result =
        await _run(() => _remote.updatePermissions(relationshipId, changes));
    return switch (result) {
      Success(value: 0) => const Result.failure(
          ServerFailure('Only the athlete can change sharing settings.')),
      Success() => const Result.success(null),
      FailureResult(failure: final f) => Result.failure(f),
    };
  }

  @override
  Future<Result<CoachingFeedback>> sendFeedback({
    required String relationshipId,
    required String authorId,
    required String body,
    String? workoutLogId,
    String? skillId,
  }) =>
      _run(() async => ConnectModels.feedback(await _remote.insertFeedback({
            'relationship_id': relationshipId,
            'author_id': authorId,
            'body': body,
            if (workoutLogId != null) 'workout_log_id': workoutLogId,
            if (skillId != null) 'skill_id': skillId,
          })));

  // ---- RPC-only lifecycle ----

  @override
  Future<Result<String>> chooseCaptain({
    required String coachId,
    String? planId,
    bool? shareWorkouts,
    bool? sharePrs,
    bool? shareSkillProgress,
    bool? shareBodyMetrics,
  }) =>
      _run(() async => await _remote.callRpc('choose_captain', {
            'p_coach_id': coachId,
            if (planId != null) 'p_plan_id': planId,
            if (shareWorkouts != null) 'p_share_workouts': shareWorkouts,
            if (sharePrs != null) 'p_share_prs': sharePrs,
            if (shareSkillProgress != null)
              'p_share_skill_progress': shareSkillProgress,
            if (shareBodyMetrics != null)
              'p_share_body_metrics': shareBodyMetrics,
          }) as String);

  @override
  Future<Result<void>> respondToRequest(String relationshipId,
          {required bool accept}) =>
      _run(() => _remote.callRpc('respond_to_coaching_request', {
            'p_relationship_id': relationshipId,
            'p_accept': accept,
          }));

  @override
  Future<Result<void>> endCoaching(String relationshipId) => _run(() =>
      _remote.callRpc('end_coaching', {'p_relationship_id': relationshipId}));

  @override
  Future<Result<String>> assignProgram({
    required String relationshipId,
    required String programId,
    DateTime? startDate,
    String? instructions,
  }) =>
      _run(() async => await _remote.callRpc('assign_program', {
            'p_relationship_id': relationshipId,
            'p_program_id': programId,
            if (startDate != null)
              'p_start_date': startDate.toIso8601String().substring(0, 10),
            if (instructions != null) 'p_instructions': instructions,
          }) as String);

  @override
  Future<Result<String>> startAssignedProgram(String assignmentId) =>
      _run(() async => await _remote.callRpc(
              'start_assigned_program', {'p_assignment_id': assignmentId})
          as String);

  @override
  Future<Result<void>> completeAssignment(String assignmentId) =>
      _run(() => _remote
          .callRpc('complete_assignment', {'p_assignment_id': assignmentId}));

  // ---- Invitations ----

  @override
  Future<Result<CreatedInvite>> createInvite({String? note, int? validDays}) =>
      _run(() async {
        final rows = await _remote.callRowsRpc('create_coaching_invitation', {
          if (note != null) 'p_note': note,
          if (validDays != null) 'p_valid_days': validDays,
        });
        return ConnectModels.createdInvite(rows.single);
      });

  @override
  Future<Result<void>> revokeInvite(String invitationId) => _run(() => _remote
      .callRpc('revoke_coaching_invitation', {'p_invitation_id': invitationId}));

  @override
  Future<Result<InvitePreview>> previewInvite(String code) => _run(() async {
        final rows = await _remote
            .callRowsRpc('preview_coaching_invitation', {'p_code': code});
        return ConnectModels.invitePreview(rows.single);
      });

  @override
  Future<Result<String>> acceptInvite(
    String code, {
    bool? shareWorkouts,
    bool? sharePrs,
    bool? shareSkillProgress,
    bool? shareBodyMetrics,
  }) =>
      _run(() async => await _remote.callRpc('accept_coaching_invitation', {
            'p_code': code,
            if (shareWorkouts != null) 'p_share_workouts': shareWorkouts,
            if (sharePrs != null) 'p_share_prs': sharePrs,
            if (shareSkillProgress != null)
              'p_share_skill_progress': shareSkillProgress,
            if (shareBodyMetrics != null)
              'p_share_body_metrics': shareBodyMetrics,
          }) as String);

  // ---- Helpers ----

  /// Exception → [Failure] mapping shared by every method.
  Future<Result<T>> _run<T>(Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }
}

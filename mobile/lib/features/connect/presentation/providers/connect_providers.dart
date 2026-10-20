import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../data/datasources/connect_remote_datasource.dart';
import '../../data/repositories/connect_repository_impl.dart';
import '../../domain/entities/connect_entities.dart';
import '../../domain/repositories/connect_repository.dart';

/// Dependency graph and read models for the CONNECT (Coach) screens.
///
/// These providers only call the existing [ConnectRepository]; every write
/// still goes through its RLS/RPC-backed methods unchanged.

final connectRemoteDataSourceProvider = Provider<ConnectRemoteDataSource>(
  (ref) => ConnectRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final connectRepositoryProvider = Provider<ConnectRepository>(
  (ref) => ConnectRepositoryImpl(ref.watch(connectRemoteDataSourceProvider)),
);

/// Unwraps a [Result] so a FutureProvider surfaces the [Failure] as its
/// error state.
T _unwrap<T>(Result<T> result) => result.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );

/// Readable message for an error coming out of these providers.
String connectErrorMessage(Object error) =>
    error is Failure ? error.message : 'Something went wrong. Try again.';

/// Approved coaches, optionally filtered by one specialty.
final coachDirectoryProvider = FutureProvider.autoDispose
    .family<List<CoachDirectoryEntry>, String?>((ref, specialty) async {
  final repo = ref.watch(connectRepositoryProvider);
  return _unwrap(await repo.getCoachDirectory(specialty: specialty));
});

/// One coach's public card (`get_coach_card`), listed or not — an invited
/// athlete's Captain can be hidden from the directory. Null when the coach
/// isn't approved.
final coachByIdProvider = FutureProvider.autoDispose
    .family<CoachDirectoryEntry?, String>((ref, coachId) async {
  final repo = ref.watch(connectRepositoryProvider);
  return _unwrap(await repo.getCoachCard(coachId));
});

/// Everything the Coach hub shows about the athlete's current Captain.
final class CaptainOverview {
  const CaptainOverview({
    required this.relationship,
    this.coach,
    this.permissions,
    this.feedback = const [],
    this.assignments = const [],
  });

  final CoachingRelationship relationship;

  /// Directory card for the coach, when listed.
  final CoachDirectoryEntry? coach;
  final CoachingPermissions? permissions;

  /// Newest first.
  final List<CoachingFeedback> feedback;
  final List<ProgramAssignment> assignments;

  bool get isActive => relationship.status == CoachingStatus.active;
  bool get isPending => relationship.status == CoachingStatus.pending;

  String get coachName =>
      coach?.displayName ?? coach?.username ?? 'Your Coach';

  /// Latest note written by the coach (not by the athlete).
  CoachingFeedback? get latestCoachFeedback {
    for (final f in feedback) {
      if (f.authorId == relationship.coachId) return f;
    }
    return null;
  }

  /// The assignment to surface: in progress first, then the newest
  /// assigned one.
  ProgramAssignment? get currentAssignment {
    for (final a in assignments) {
      if (a.status == AssignmentStatus.inProgress) return a;
    }
    for (final a in assignments) {
      if (a.status == AssignmentStatus.assigned) return a;
    }
    return null;
  }
}

/// The signed-in athlete's active (or pending) Captain, or null when they
/// don't have one. Guests never have one.
final myCaptainProvider =
    FutureProvider.autoDispose<CaptainOverview?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isGuest) return null;

  final repo = ref.watch(connectRepositoryProvider);
  final relationships = _unwrap(await repo.getMyRelationships());

  CoachingRelationship? pick(CoachingStatus status) {
    for (final r in relationships) {
      if (r.athleteId == user.id && r.status == status) return r;
    }
    return null;
  }

  final rel = pick(CoachingStatus.active) ?? pick(CoachingStatus.pending);
  if (rel == null) return null;

  final (permissions, feedback, assignments, card) = await (
    repo.getPermissions(rel.id),
    repo.getFeedback(rel.id),
    repo.getAssignments(rel.id),
    repo.getCoachCard(rel.coachId),
  ).wait;

  return CaptainOverview(
    relationship: rel,
    coach: card.valueOrNull,
    permissions: permissions.valueOrNull,
    feedback: feedback.valueOrNull ?? const [],
    assignments: assignments.valueOrNull ?? const [],
  );
});

// ---------------------------------------------------------------------------
// Captain Hub (the coach's side)
// ---------------------------------------------------------------------------

/// The signed-in user's Captain Hub, or null when they have never applied
/// to be a Captain. Guests never have one.
final captainHubProvider = FutureProvider.autoDispose<CaptainHub?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isGuest) return null;
  final repo = ref.watch(connectRepositoryProvider);
  return _unwrap(await repo.getCaptainHub());
});

/// Recent completed workouts of one athlete, as their Captain sees them.
/// Empty when the athlete has workouts sharing off.
final clientWorkoutsProvider = FutureProvider.autoDispose
    .family<List<ClientWorkout>, String>((ref, athleteId) async {
  final repo = ref.watch(connectRepositoryProvider);
  return _unwrap(await repo.getClientWorkouts(athleteId, limit: 20));
});

/// Feedback thread for one relationship, newest first.
final relationshipFeedbackProvider = FutureProvider.autoDispose
    .family<List<CoachingFeedback>, String>((ref, relationshipId) async {
  final repo = ref.watch(connectRepositoryProvider);
  return _unwrap(await repo.getFeedback(relationshipId));
});

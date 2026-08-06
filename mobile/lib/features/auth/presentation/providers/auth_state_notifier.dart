import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_providers.dart';

/// Holds the current user session and exposes the actions screens call.
///
/// This is the single source of truth for "who is logged in right now" —
/// [AppRouter]'s redirect logic watches this to decide whether to show
/// Auth screens or the authenticated app shell.
class AuthStateNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    return ref.watch(authRepositoryProvider).getCurrentUser();
  }

  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(signInWithEmailProvider)
        .call(email: email, password: password);
    return result.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (failure) {
        state = AsyncData(state.valueOrNull);
        return failure;
      },
    );
  }

  Future<Failure?> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(registerWithEmailProvider)
        .call(email: email, password: password);
    return result.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (failure) async {
        if (failure is EmailAlreadyInUseFailure) {
          // Attempt automatic sign in if account already exists
          return await signIn(email: email, password: password);
        }
        state = AsyncData(state.valueOrNull);
        return failure;
      },
    );
  }

  Future<Failure?> continueAsGuest() async {
    state = const AsyncLoading();
    final result = await ref.read(continueAsGuestProvider).call();
    return result.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (failure) {
        state = AsyncData(state.valueOrNull);
        return failure;
      },
    );
  }

  Future<Failure?> sendPasswordReset(String email) async {
    final result = await ref.read(sendPasswordResetProvider).call(email);
    return result.failureOrNull;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(signOutProvider).call();
    state = const AsyncData(null);
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, UserEntity?>(
  AuthStateNotifier.new,
);

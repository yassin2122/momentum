import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_change.dart';
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
    final repository = ref.watch(authRepositoryProvider);

    // Sessions also change outside this notifier's own methods — deep
    // links (OAuth callback, password-reset link), token expiry, sign-out
    // on another device — so mirror every session event into [state].
    final subscription = repository.watchAuthChanges().listen(
          _onAuthChange,
          // A failed refresh or an expired reset link arrives as a stream
          // error; the session state itself is still reported by the next
          // event, so there's nothing to update here.
          onError: (Object _) {},
        );
    ref.onDispose(subscription.cancel);

    return repository.getCurrentUser();
  }

  void _onAuthChange(AuthChange change) {
    if (change.kind == AuthChangeKind.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    } else if (change.kind == AuthChangeKind.signedOut) {
      ref.read(passwordRecoveryProvider.notifier).state = false;
    }
    if (state.valueOrNull != change.user) state = AsyncData(change.user);
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
    String? displayName,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(registerWithEmailProvider).call(
          email: email,
          password: password,
          displayName: displayName,
        );
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

  /// Sets a new password during the reset flow. On success the recovery
  /// session becomes a normal one and the router leaves the reset screen.
  Future<Failure?> updatePassword(String newPassword) async {
    final result = await ref.read(updatePasswordProvider).call(newPassword);
    if (result.isSuccess) {
      ref.read(passwordRecoveryProvider.notifier).state = false;
    }
    return result.failureOrNull;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(signOutProvider).call();
    ref.read(passwordRecoveryProvider.notifier).state = false;
    state = const AsyncData(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, UserEntity?>(
  AuthStateNotifier.new,
);

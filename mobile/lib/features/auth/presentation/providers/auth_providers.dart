import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/mfa.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/continue_as_guest.dart';
import '../../domain/usecases/register_with_email.dart';
import '../../domain/usecases/send_password_reset.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_password.dart';

/// Dependency injection graph for the Auth feature.
///
/// Each provider builds on the one below it, so swapping an implementation
/// (e.g. a fake repository in tests) only means overriding one provider —
/// nothing else in this graph needs to change.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final signInWithEmailProvider = Provider<SignInWithEmail>((ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
});

final registerWithEmailProvider = Provider<RegisterWithEmail>((ref) {
  return RegisterWithEmail(ref.watch(authRepositoryProvider));
});

final continueAsGuestProvider = Provider<ContinueAsGuest>((ref) {
  return ContinueAsGuest(ref.watch(authRepositoryProvider));
});

final sendPasswordResetProvider = Provider<SendPasswordReset>((ref) {
  return SendPasswordReset(ref.watch(authRepositoryProvider));
});

final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

final updatePasswordProvider = Provider<UpdatePassword>((ref) {
  return UpdatePassword(ref.watch(authRepositoryProvider));
});

/// True while the user holds a password-recovery session (they opened a
/// reset link) and hasn't set a new password yet. The router keeps them
/// on the reset-password screen until this clears.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// Confirmed authenticator-app factors on the signed-in account.
final mfaFactorsProvider =
    FutureProvider.autoDispose<List<MfaFactor>>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getMfaFactors();
  if (result.failureOrNull case final f?) throw f.message;
  return result.valueOrNull ?? const [];
});

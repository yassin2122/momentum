/// Domain-level representation of the current user.
///
/// This is what the rest of the app (dashboard, workouts, etc.) will depend
/// on — never the Supabase User type directly. That keeps every other
/// feature decoupled from the auth provider we happen to use today.
final class UserEntity {
  const UserEntity({
    required this.id,
    required this.isGuest,
    this.email,
    this.displayName,
  });

  /// Supabase user id. For guest sessions this is the anonymous session's
  /// id (Supabase anonymous sign-in still issues a stable user id).
  final String id;

  /// True when the user is in Guest Mode (anonymous Supabase session).
  final bool isGuest;

  final String? email;
  final String? displayName;

  UserEntity copyWith({
    String? id,
    bool? isGuest,
    String? email,
    String? displayName,
  }) {
    return UserEntity(
      id: id ?? this.id,
      isGuest: isGuest ?? this.isGuest,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isGuest == other.isGuest &&
          email == other.email &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(id, isGuest, email, displayName);
}

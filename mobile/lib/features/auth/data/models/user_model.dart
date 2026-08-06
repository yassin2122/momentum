import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/user_entity.dart';

/// Data-layer model that knows how to build a [UserEntity] from Supabase's
/// [supabase.User] type. This is the translation boundary — nothing outside
/// the data layer should ever import `supabase_flutter`'s User type.
final class UserModel {
  const UserModel._();

  static UserEntity fromSupabaseUser(supabase.User user) {
    return UserEntity(
      id: user.id,
      isGuest: user.isAnonymous,
      email: user.email,
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }
}

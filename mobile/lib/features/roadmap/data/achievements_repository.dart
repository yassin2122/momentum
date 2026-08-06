import 'package:gym_app/lib/core/supabase/supabase_client.dart';
import '../../../core/models/achievement.dart';

class AchievementsRepository {
  const AchievementsRepository();

  Future<List<Achievement>> fetchCatalog() async {
    final rows = await supabase.from('achievements').select().order('sort_order');
    return rows.map((r) => Achievement.fromJson(r)).toList();
  }

  Future<List<UserAchievement>> fetchMyUnlocked() async {
    final rows = await supabase.from('user_achievements').select();
    return rows.map((r) => UserAchievement.fromJson(r)).toList();
  }
}

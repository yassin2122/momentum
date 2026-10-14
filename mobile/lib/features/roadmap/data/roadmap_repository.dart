import '../../../main.dart' show supabase;
import '../../../core/models/roadmap.dart';

/// Real Supabase-backed replacement for `SeedRoadmapContentRepository`.
/// Reads are plain `.select()` calls (RLS already scopes progress rows to
/// the caller). Writes to XP/status/completion NEVER happen here — they
/// only happen through the `award_stage_xp` / `award_xp` /
/// `complete_roadmap_workout` RPCs, matching the DB's RLS design (those
/// tables have no client-writable policy at all, by design).
class RoadmapRepository {
  const RoadmapRepository();

  Future<List<RoadmapCategory>> fetchCategories() async {
    final rows = await supabase
        .from('roadmap_categories')
        .select()
        .order('sort_order');
    return rows.map((r) => RoadmapCategory.fromJson(r)).toList();
  }

  Future<List<Skill>> fetchSkillsForCategory(String categoryId) async {
    final rows = await supabase
        .from('skills')
        .select()
        .eq('roadmap_category_id', categoryId)
        .eq('is_active', true)
        .order('sort_order');
    return rows.map((r) => Skill.fromJson(r)).toList();
  }

  Future<List<SkillPrerequisite>> fetchPrerequisitesForSkill(String skillId) async {
    final rows = await supabase
        .from('skill_prerequisites')
        .select()
        .eq('skill_id', skillId);
    return rows.map((r) => SkillPrerequisite.fromJson(r)).toList();
  }

  /// Elite challenges (Victorian, Maltese, ...) are just `skills` rows with
  /// `is_elite_challenge = true`, gated by a `skill_prerequisites` row
  /// pointing back at [skillId] with `required_status = 'legendary'`
  /// (migration 0019). Two-step query since Supabase's PostgREST join
  /// syntax needs a known FK constraint name we didn't want to hardcode.
  Future<List<Skill>> fetchEliteChallengesForSkill(String skillId) async {
    final edges = await supabase
        .from('skill_prerequisites')
        .select('skill_id')
        .eq('prerequisite_skill_id', skillId)
        .eq('required_status', 'legendary');
    final challengeSkillIds = edges.map((e) => e['skill_id'] as String).toList();
    if (challengeSkillIds.isEmpty) return [];

    final rows = await supabase
        .from('skills')
        .select()
        .inFilter('id', challengeSkillIds)
        .eq('is_elite_challenge', true);
    return rows.map((r) => Skill.fromJson(r)).toList();
  }

  Future<List<SkillStage>> fetchStagesForSkill(String skillId) async {
    final rows = await supabase
        .from('skill_stages')
        .select()
        .eq('skill_id', skillId)
        .order('stage_order');
    return rows.map((r) => SkillStage.fromJson(r)).toList();
  }

  Future<List<RoadmapObjective>> fetchObjectivesForSkill(String skillId) async {
    final rows = await supabase
        .from('objectives')
        .select()
        .eq('skill_id', skillId)
        .order('sort_order');
    return rows.map((r) => RoadmapObjective.fromJson(r)).toList();
  }

  /// All of the current user's skill_progress rows. RLS already restricts
  /// this to `auth.uid()` — no need to filter by user_id client-side, but
  /// harmless to do so for clarity/caching-key purposes.
  Future<List<SkillProgress>> fetchMySkillProgress() async {
    final rows = await supabase.from('skill_progress').select();
    return rows.map((r) => SkillProgress.fromJson(r)).toList();
  }

  Future<List<UserSkillStageProgress>> fetchMyStageProgressForSkill(String skillId) async {
    // Join through skill_stages to filter by skill_id (user_skill_stage_progress
    // doesn't carry skill_id directly — it belongs to a stage, which belongs
    // to a skill).
    final rows = await supabase
        .from('user_skill_stage_progress')
        .select('*, skill_stages!inner(skill_id)')
        .eq('skill_stages.skill_id', skillId);
    return rows.map((r) => UserSkillStageProgress.fromJson(r)).toList();
  }

  Future<List<UserObjectiveProgress>> fetchMyObjectiveProgressForSkill(String skillId) async {
    final rows = await supabase
        .from('user_objective_progress')
        .select('*, objectives!inner(skill_id)')
        .eq('objectives.skill_id', skillId);
    return rows.map((r) => UserObjectiveProgress.fromJson(r)).toList();
  }

  /// Awards XP at the node level via the `award_stage_xp` RPC — the ONLY
  /// path that can move current_xp. Rolls up into skill_progress
  /// automatically server-side.
  Future<void> awardStageXp({
    required String skillStageId,
    required int amount,
    required String source, // xp_source enum value, e.g. 'objective_completion'
    String? referenceTable,
    String? referenceId,
  }) async {
    await supabase.rpc('award_stage_xp', params: {
      'p_user_id': supabase.auth.currentUser!.id,
      'p_skill_stage_id': skillStageId,
      'p_amount': amount,
      'p_source': source,
      'p_reference_table': referenceTable,
      'p_reference_id': referenceId,
    });
  }

  /// Completes a fixed roadmap workout via the `complete_roadmap_workout`
  /// RPC. `exerciseResults` shape must match what the RPC expects:
  /// [{exercise_id, achieved_sets, achieved_reps, achieved_hold_seconds}, ...]
  Future<String> completeRoadmapWorkout({
    required String roadmapWorkoutId,
    required List<Map<String, dynamic>> exerciseResults,
  }) async {
    final result = await supabase.rpc('complete_roadmap_workout', params: {
      'p_roadmap_workout_id': roadmapWorkoutId,
      'p_exercise_results': exerciseResults,
    });
    return result as String; // returns the new roadmap_workout_logs.id
  }
}

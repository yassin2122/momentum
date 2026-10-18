import 'dart:ui';

import '../../../../core/theme/app_colors.dart';

// =====================================================================
// SAMPLE DATA — presentation only.
//
// The skill roadmap repositories (`features/roadmap/data/`) aren't wired
// yet, so the Progress screens (Phases → Universe → Planet → Skill) and
// the Dashboard's streak/momentum/skill cards read from this file. Every
// value here is placeholder content from the Momentum canvas designs.
//
// To go live, replace these constants with providers backed by the
// roadmap repositories — the screens only depend on the view types
// below, not on where the values come from.
// =====================================================================

/// Asset paths for the game art.
abstract final class ProgressArt {
  static const String _planets = 'assets/images/planets';
  static const String _phases = 'assets/images/phases';
  static const String _hub = 'assets/images/hub';

  static const String planetBalance = '$_planets/earth.png';
  static const String planetPush = '$_planets/mars.png';
  static const String planetPull = '$_planets/moon.png';
  static const String planetCore = '$_planets/gold.png';
  static const String planetLegs = '$_planets/lava.png';
  static const String planetLockedA = '$_planets/ringed.png';
  static const String planetLockedB = '$_planets/flare.png';

  static const String universeBand = '$_phases/universe-band.jpg';

  static const String dashboardMascot = '$_hub/dash-mascot.jpg';
  static const String dashboardBody = '$_hub/dash-body.jpg';
  static const String skillMuscleUp = '$_hub/skill-muscleup.jpg';
  static const String skillFrontLever = '$_hub/skill-frontlever.jpg';
  static const String skillHandstand = '$_hub/skill-handstand.jpg';
}

/// Top-of-screen game counters (streak / XP / stars).
final class ProgressHud {
  const ProgressHud({
    required this.streakDays,
    required this.bestStreakDays,
    required this.xp,
    required this.stars,
    required this.momentum,
    required this.weekDone,
    required this.todayIndex,
  });

  final int streakDays;
  final int bestStreakDays;
  final int xp;
  final int stars;

  /// 0–1 weekly consistency score shown as "Momentum".
  final double momentum;

  /// Mon→Sun: whether a workout was logged that day.
  final List<bool> weekDone;

  /// 0 = Monday.
  final int todayIndex;
}

const ProgressHud sampleHud = ProgressHud(
  streakDays: 12,
  bestStreakDays: 18,
  xp: 3420,
  stars: 31,
  momentum: 0.82,
  weekDone: [true, true, true, true, false, false, false],
  todayIndex: 4,
);

/// One day on the Dashboard's week strip.
enum WeekDayStatus { completed, today, planned, rest }

final class WeekPlanDay {
  const WeekPlanDay(this.status, {this.session});

  final WeekDayStatus status;

  /// Session type for planned/today days ("Pull", "Legs").
  final String? session;
}

/// Mon → Sun for the current week. Index 4 (Friday) is today.
const List<WeekPlanDay> sampleWeek = [
  WeekPlanDay(WeekDayStatus.completed, session: 'Push'),
  WeekPlanDay(WeekDayStatus.completed, session: 'Pull'),
  WeekPlanDay(WeekDayStatus.rest),
  WeekPlanDay(WeekDayStatus.completed, session: 'Legs'),
  WeekPlanDay(WeekDayStatus.today, session: 'Push'),
  WeekPlanDay(WeekDayStatus.planned, session: 'Pull'),
  WeekPlanDay(WeekDayStatus.rest),
];

/// True once today's planned session has been logged (sample).
const bool sampleTodayDone = false;

/// Today's planned workout from the coach (sample). The CTA starts the
/// user's template with the same name when one exists.
final class TodayPlan {
  const TodayPlan({
    required this.title,
    required this.exercises,
    required this.minutes,
    required this.lastCompletedDaysAgo,
  });

  final String title;
  final List<String> exercises;
  final int minutes;
  final int lastCompletedDaysAgo;
}

const TodayPlan sampleTodayPlan = TodayPlan(
  title: 'Push Day',
  exercises: [
    'Push-ups',
    'Dips',
    'Pike push-ups',
    'Pseudo planche push-ups',
    'Diamond push-ups',
    'Handstand hold',
    'Plank to push-up',
    'Hollow body hold',
  ],
  minutes: 70,
  lastCompletedDaysAgo: 3,
);

/// One of the three phases (galaxies) on the Phases screen.
final class GalaxyPhase {
  const GalaxyPhase({
    required this.number,
    required this.title,
    required this.tags,
    required this.tagline,
    required this.color,
    required this.progress,
    required this.unlocked,
    required this.lockedNote,
  });

  final int number;
  final String title;
  final String tags;
  final String tagline;
  final Color color;
  final double progress;
  final bool unlocked;
  final String lockedNote;
}

const List<GalaxyPhase> samplePhases = [
  GalaxyPhase(
    number: 1,
    title: 'THE ORIGIN',
    tags: 'DISCIPLINE  /  HABITS  /  FIRST STEPS',
    tagline: 'It all begins with a decision.\nThe first step toward a '
        'stronger you.',
    color: AppColors.phaseOrigin,
    progress: 0.57,
    unlocked: true,
    lockedNote: '',
  ),
  GalaxyPhase(
    number: 2,
    title: 'THE ASCENSION',
    tags: 'CONTROL  /  PROGRESS  /  MASTERY',
    tagline: "You don't just get stronger.\nYou learn to control it.",
    color: AppColors.phaseAscension,
    progress: 0,
    unlocked: false,
    lockedNote: 'Opens when the Origin is complete',
  ),
  GalaxyPhase(
    number: 3,
    title: 'THE SINGULARITY',
    tags: 'BEYOND  /  LIMITS  /  FREEDOM',
    tagline: 'Not the end.\nThe ultimate version of you.',
    color: AppColors.phaseSingularity,
    progress: 0,
    unlocked: false,
    lockedNote: 'Opens when the Ascension is complete',
  ),
];

/// Certification tier a skill has reached.
enum SkillTier {
  none('Not certified'),
  complete('Complete'),
  master('Master'),
  legendary('Legendary');

  const SkillTier(this.label);
  final String label;

  /// Stars on the level path: one per tier.
  int get stars => index;
}

enum SkillNodeState { done, current, locked }

final class SkillObjective {
  const SkillObjective(this.label, {this.done = 0, this.target = 1});

  final String label;
  final int done;
  final int target;

  bool get isComplete => done >= target;
}

final class TierGoal {
  const TierGoal({required this.tier, required this.goal});

  final SkillTier tier;
  final String goal;
}

/// One level node on a planet's path, and its Skill detail page.
final class PlanetSkill {
  const PlanetSkill({
    required this.id,
    required this.name,
    required this.state,
    required this.tier,
    this.progress = 0,
    this.xp = 0,
    this.xpGoal = 500,
    this.tierGoals = const [
      TierGoal(tier: SkillTier.complete, goal: '1 clean rep'),
      TierGoal(tier: SkillTier.master, goal: '5 clean reps'),
      TierGoal(tier: SkillTier.legendary, goal: '10 strict reps'),
    ],
    this.objectives = const [],
    this.captainNote,
    this.image,
    this.nextMilestone,
  });

  final String id;
  final String name;
  final SkillNodeState state;
  final SkillTier tier;

  /// 0–1 toward the next tier.
  final double progress;
  final int xp;
  final int xpGoal;
  final List<TierGoal> tierGoals;
  final List<SkillObjective> objectives;
  final String? captainNote;
  final String? image;

  /// The next concrete step toward the goal, e.g. "Tuck lever 10s".
  final String? nextMilestone;

  int get objectivesDone => objectives.where((o) => o.isComplete).length;

  /// The tier this skill is working toward.
  SkillTier get nextTier => tier == SkillTier.legendary
      ? SkillTier.legendary
      : SkillTier.values[tier.index + 1];
}

/// A planet (muscle group) in the galaxy.
final class SkillPlanet {
  const SkillPlanet({
    required this.id,
    required this.name,
    required this.image,
    required this.glow,
    required this.skills,
    required this.eliteTrialName,
  });

  final String id;
  final String name;
  final String image;
  final Color glow;

  /// Exactly seven, in path order (first → summit).
  final List<PlanetSkill> skills;
  final String eliteTrialName;

  int get certified => skills.where((s) => s.tier != SkillTier.none).length;
  int get stars => skills.fold(0, (sum, s) => sum + s.tier.stars);
  int get totalStars => skills.length * 3;

  double get progress {
    final earned = skills.fold<double>(0, (sum, s) {
      if (s.state == SkillNodeState.done) return sum + 1;
      if (s.state == SkillNodeState.current) return sum + s.progress;
      return sum;
    });
    return earned / skills.length;
  }

  PlanetSkill? get current {
    for (final s in skills) {
      if (s.state == SkillNodeState.current) return s;
    }
    return null;
  }

  /// The elite trial opens once every skill below the summit is Master.
  bool get eliteUnlocked => skills
      .where((s) => s.state == SkillNodeState.done)
      .every((s) => s.tier.index >= SkillTier.master.index);
}

PlanetSkill _done(String id, String name, SkillTier tier) => PlanetSkill(
      id: id,
      name: name,
      state: SkillNodeState.done,
      tier: tier,
      progress: 1,
      xp: 500,
      objectives: [SkillObjective('Certify $name', done: 1)],
    );

PlanetSkill _locked(String id, String name) => PlanetSkill(
      id: id,
      name: name,
      state: SkillNodeState.locked,
      tier: SkillTier.none,
    );

final List<SkillPlanet> samplePlanets = [
  SkillPlanet(
    id: 'pull',
    name: 'Pull',
    image: ProgressArt.planetPull,
    glow: AppColors.gameBlue,
    eliteTrialName: 'Elite trial',
    skills: [
      _done('dead-hang', 'Dead hang', SkillTier.legendary),
      _done('scapular-pull', 'Scapular pull', SkillTier.master),
      _done('australian-row', 'Australian row', SkillTier.master),
      _done('pull-up', 'Pull-up', SkillTier.complete),
      _done('chest-to-bar', 'Chest-to-bar', SkillTier.complete),
      const PlanetSkill(
        id: 'muscle-up',
        name: 'Muscle up',
        state: SkillNodeState.current,
        tier: SkillTier.none,
        progress: 0.68,
        xp: 340,
        nextMilestone: 'Negatives 5 × 5s',
        image: ProgressArt.skillMuscleUp,
        objectives: [
          SkillObjective('8 strict pull-ups', done: 1),
          SkillObjective('5 chest-to-bar pull-ups', done: 1),
          SkillObjective('10 straight-bar dips', done: 1),
          SkillObjective('5 negative muscle-ups, 5 s lowering',
              done: 3, target: 5),
          SkillObjective('1 clean muscle up'),
        ],
        captainNote:
            'Keep the false grip on negatives. Film one set for me this week.',
      ),
      _locked('strict-muscle-up', 'Strict muscle up'),
    ],
  ),
  SkillPlanet(
    id: 'balance',
    name: 'Balance',
    image: ProgressArt.planetBalance,
    glow: AppColors.success,
    eliteTrialName: 'Elite trial',
    skills: [
      _done('wall-plank', 'Wall plank', SkillTier.legendary),
      _done('crow-pose', 'Crow pose', SkillTier.master),
      _done('wall-handstand', 'Wall handstand', SkillTier.master),
      _done('pike-hold', 'Pike hold', SkillTier.master),
      _done('l-sit', 'L-sit', SkillTier.complete),
      const PlanetSkill(
        id: 'handstand',
        name: 'Handstand',
        state: SkillNodeState.current,
        tier: SkillTier.none,
        progress: 0.81,
        xp: 405,
        nextMilestone: 'Freestanding 10s',
        image: ProgressArt.skillHandstand,
        tierGoals: [
          TierGoal(tier: SkillTier.complete, goal: '10 s freestanding'),
          TierGoal(tier: SkillTier.master, goal: '30 s freestanding'),
          TierGoal(tier: SkillTier.legendary, goal: '60 s, straight line'),
        ],
        objectives: [
          SkillObjective('45 s chest-to-wall hold', done: 1),
          SkillObjective('20 heel pulls off the wall', done: 1),
          SkillObjective('10 kick-ups to balance', done: 1),
          SkillObjective('5 s freestanding, 5 times', done: 4, target: 5),
          SkillObjective('10 s freestanding'),
        ],
        captainNote: 'Stack the hips over the shoulders before you kick.',
      ),
      _locked('press-handstand', 'Press to handstand'),
    ],
  ),
  SkillPlanet(
    id: 'push',
    name: 'Push',
    image: ProgressArt.planetPush,
    glow: AppColors.accent,
    eliteTrialName: 'Elite trial',
    skills: [
      _done('incline-push-up', 'Incline push-up', SkillTier.legendary),
      _done('push-up', 'Push-up', SkillTier.master),
      _done('dip', 'Straight-bar dip', SkillTier.complete),
      const PlanetSkill(
        id: 'pike-push-up',
        name: 'Pike push-up',
        state: SkillNodeState.current,
        tier: SkillTier.none,
        progress: 0.6,
        xp: 300,
        objectives: [
          SkillObjective('3 × 10 push-ups', done: 1),
          SkillObjective('3 × 8 elevated pike push-ups', done: 1),
          SkillObjective('3 × 5 pike push-ups', done: 2, target: 3),
          SkillObjective('1 × 10 pike push-ups'),
        ],
      ),
      _locked('archer-push-up', 'Archer push-up'),
      _locked('hspu', 'Wall handstand push-up'),
      _locked('planche-lean', 'Planche lean'),
    ],
  ),
  SkillPlanet(
    id: 'core',
    name: 'Core',
    image: ProgressArt.planetCore,
    glow: AppColors.gameGold,
    eliteTrialName: 'Elite trial',
    skills: [
      _done('hollow-hold', 'Hollow hold', SkillTier.master),
      _done('hanging-knee-raise', 'Hanging knee raise', SkillTier.complete),
      const PlanetSkill(
        id: 'front-lever',
        name: 'Front lever',
        state: SkillNodeState.current,
        tier: SkillTier.none,
        progress: 0.24,
        xp: 120,
        nextMilestone: 'Tuck lever 10s',
        image: ProgressArt.skillFrontLever,
        tierGoals: [
          TierGoal(tier: SkillTier.complete, goal: '5 s tuck lever'),
          TierGoal(tier: SkillTier.master, goal: '10 s straddle lever'),
          TierGoal(tier: SkillTier.legendary, goal: '10 s full lever'),
        ],
        objectives: [
          SkillObjective('20 s hollow hold', done: 1),
          SkillObjective('10 hanging leg raises', done: 4, target: 10),
          SkillObjective('3 × 5 s tuck lever'),
        ],
      ),
      _locked('toes-to-bar', 'Toes to bar'),
      _locked('dragon-flag', 'Dragon flag'),
      _locked('v-sit', 'V-sit'),
      _locked('full-front-lever', 'Full front lever'),
    ],
  ),
  SkillPlanet(
    id: 'legs',
    name: 'Legs',
    image: ProgressArt.planetLegs,
    glow: AppColors.heroGlow,
    eliteTrialName: 'Elite trial',
    skills: [
      _done('squat', 'Bodyweight squat', SkillTier.complete),
      const PlanetSkill(
        id: 'split-squat',
        name: 'Split squat',
        state: SkillNodeState.current,
        tier: SkillTier.none,
        progress: 0.5,
        xp: 250,
        objectives: [
          SkillObjective('3 × 20 squats', done: 1),
          SkillObjective('3 × 10 split squats each leg', done: 1, target: 2),
        ],
      ),
      _locked('bulgarian', 'Bulgarian split squat'),
      _locked('shrimp-squat', 'Shrimp squat'),
      _locked('nordic-curl', 'Nordic curl'),
      _locked('pistol-squat', 'Pistol squat'),
      _locked('dragon-squat', 'Dragon squat'),
    ],
  ),
];

/// Universe display order: the selected planet sits in the middle.
const String sampleSelectedPlanetId = 'pull';

SkillPlanet? planetById(String id) {
  for (final p in samplePlanets) {
    if (p.id == id) return p;
  }
  return null;
}

/// Finds a skill and the planet it lives on.
({SkillPlanet planet, PlanetSkill skill})? skillById(String id) {
  for (final p in samplePlanets) {
    for (final s in p.skills) {
      if (s.id == id) return (planet: p, skill: s);
    }
  }
  return null;
}

/// The three skill rings on the Dashboard.
const List<String> sampleDashboardSkillIds = [
  'muscle-up',
  'front-lever',
  'handstand',
];

/// Profile → Personal records.
const List<(String, String)> samplePersonalRecords = [
  ('Max pull-ups', '14 reps'),
  ('Weighted dip', '+20 kg × 5'),
  ('Handstand hold', '25 s'),
];

/// Profile → totals.
const int sampleWorkoutCount = 48;

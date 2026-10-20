/// Which side of the body map is showing.
enum BodyView { front, back }

/// A muscle region on the body map.
///
/// Finer than the library's 17 `muscle_groups`: one library group can light
/// several regions (e.g. `shoulders` → all three deltoid heads), see
/// `MuscleMapping`. Left and right halves are drawn separately but are the
/// same [Muscle] — workout logs don't record a side.
///
/// [views] lists the sides where the anatomy assets draw the region; the
/// enum name is the region's stable id (`<g id="…">` in
/// `assets/anatomy/body_*.svg`). Renaming a value means rebuilding them.
enum Muscle {
  chest('Chest', {BodyView.front}),
  deltAnterior('Front delts', {BodyView.front}),
  deltLateral('Side delts', {BodyView.front, BodyView.back}),
  deltPosterior('Rear delts', {BodyView.back}),
  biceps('Biceps', {BodyView.front}),
  triceps('Triceps', {BodyView.front, BodyView.back}),
  forearms('Forearms', {BodyView.front, BodyView.back}),
  upperAbs('Upper abs', {BodyView.front}),
  lowerAbs('Lower abs', {BodyView.front}),
  obliques('Obliques', {BodyView.front, BodyView.back}),
  adductors('Adductors', {BodyView.front, BodyView.back}),
  quadriceps('Quadriceps', {BodyView.front}),
  traps('Traps', {BodyView.front, BodyView.back}),
  upperBack('Upper back', {BodyView.back}),
  lats('Lats', {BodyView.front, BodyView.back}),
  // The anatomy art has no erector spinae shape, so lower back is tracked
  // but not drawn (an empty set — never fake a region).
  lowerBack('Lower back', <BodyView>{}),
  glutes('Glutes', {BodyView.front, BodyView.back}),
  hamstrings('Hamstrings', {BodyView.front, BodyView.back}),
  calves('Calves', {BodyView.front, BodyView.back});

  const Muscle(this.label, this.views);

  final String label;
  final Set<BodyView> views;
}

/// How an exercise works a muscle.
enum Involvement { primary, secondary }

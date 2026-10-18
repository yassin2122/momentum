/// Which side of the body map is showing.
enum BodyView { front, back }

/// A muscle region on the body map.
///
/// Finer than the library's 17 `muscle_groups`: one library group can light
/// several regions (e.g. `shoulders` → all three deltoid heads), see
/// `MuscleMapping`. Left and right halves are drawn separately but are the
/// same [Muscle] — workout logs don't record a side.
enum Muscle {
  chest('Chest', {BodyView.front}),
  deltAnterior('Front delts', {BodyView.front}),
  deltLateral('Side delts', {BodyView.front, BodyView.back}),
  deltPosterior('Rear delts', {BodyView.back}),
  biceps('Biceps', {BodyView.front}),
  triceps('Triceps', {BodyView.back}),
  forearms('Forearms', {BodyView.front, BodyView.back}),
  upperAbs('Upper abs', {BodyView.front}),
  lowerAbs('Lower abs', {BodyView.front}),
  obliques('Obliques', {BodyView.front}),
  adductors('Adductors', {BodyView.front}),
  quadriceps('Quadriceps', {BodyView.front}),
  traps('Traps', {BodyView.back}),
  upperBack('Upper back', {BodyView.back}),
  lats('Lats', {BodyView.back}),
  lowerBack('Lower back', {BodyView.back}),
  glutes('Glutes', {BodyView.back}),
  hamstrings('Hamstrings', {BodyView.back}),
  calves('Calves', {BodyView.front, BodyView.back});

  const Muscle(this.label, this.views);

  final String label;
  final Set<BodyView> views;
}

/// How an exercise works a muscle.
enum Involvement { primary, secondary }

/// The user's app-open streak, as returned by `record_app_open`.
///
/// Computed only by the server (`bump_streak`): +1 per new active day,
/// kept through one or two missed days, lost on the third in a row.
final class StreakStatus {
  const StreakStatus({
    required this.current,
    required this.longest,
    this.lastActiveDate,
  });

  final int current;
  final int longest;
  final DateTime? lastActiveDate;

  factory StreakStatus.fromJson(Map<String, dynamic> json) => StreakStatus(
        current: (json['current_streak'] as num?)?.toInt() ?? 0,
        longest: (json['longest_streak'] as num?)?.toInt() ?? 0,
        lastActiveDate: DateTime.tryParse(
            json['last_activity_date'] as String? ?? ''),
      );
}

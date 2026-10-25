import '../../domain/entities/body_progress.dart';
import '../../domain/entities/recovery.dart';

/// PostgREST row ↔ entity mapping for the analytics tables.
abstract final class AnalyticsRows {
  /// `YYYY-MM-DD` for a local calendar date (Postgres `date`).
  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parses a Postgres `date` as a local calendar date.
  static DateTime? parseDate(Object? v) {
    if (v is! String || v.length < 10) return null;
    final p = DateTime.tryParse(v.substring(0, 10));
    return p == null ? null : DateTime(p.year, p.month, p.day);
  }

  static DateTime parseTimestamp(Object? v) =>
      (v is String ? DateTime.tryParse(v)?.toLocal() : null) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static double? _num(Object? v) => v is num ? v.toDouble() : null;

  // ── Body ────────────────────────────────────────────────────────────

  static BodyEntry entry(Map<String, dynamic> r) => BodyEntry(
        id: r['id'] as String,
        loggedOn: parseDate(r['logged_at']) ?? parseTimestamp(r['created_at']),
        values: {
          for (final m in BodyMeasure.values)
            if (_num(r[m.column]) != null) m: _num(r[m.column])!,
        },
        note: r['note'] as String?,
        createdAt: parseTimestamp(r['created_at']),
      );

  static Map<String, dynamic> entryRow(NewBodyEntry e) => {
        'logged_at': date(e.loggedOn),
        for (final v in e.values.entries) v.key.column: v.value,
        if (e.note != null && e.note!.trim().isNotEmpty) 'note': e.note!.trim(),
      };

  static BodyGoal? goal(Map<String, dynamic>? r) {
    final target = _num(r?['target_weight_kg']);
    if (r == null || target == null) return null;
    return BodyGoal(
      targetWeightKg: target,
      startWeightKg: _num(r['start_weight_kg']),
      targetDate: parseDate(r['target_date']),
      createdAt: parseTimestamp(r['created_at']),
    );
  }

  static ProgressPhoto photo(Map<String, dynamic> r, {String? url}) =>
      ProgressPhoto(
        id: r['id'] as String,
        storagePath: r['storage_path'] as String,
        pose: PhotoPose.fromDb(r['pose'] as String?),
        takenOn: parseDate(r['taken_on']) ?? parseTimestamp(r['created_at']),
        note: r['note'] as String?,
        createdAt: parseTimestamp(r['created_at']),
        url: url,
      );

  // ── Recovery ────────────────────────────────────────────────────────

  static RecoveryCheckin? checkin(Map<String, dynamic> r) {
    final day = parseDate(r['checkin_date']);
    final sleep = _num(r['sleep_hours']);
    final Object? soreness = r['soreness'];
    final Object? energy = r['energy'];
    final Object? fatigue = r['fatigue'];
    if (day == null || sleep == null || soreness is! num ||
        energy is! num || fatigue is! num) {
      return null;
    }
    final Object? quality = r['sleep_quality'];
    return RecoveryCheckin(
      id: r['id'] as String?,
      date: day,
      sleepHours: sleep,
      sleepQuality: quality is num ? quality.toInt() : null,
      soreness: soreness.toInt(),
      energy: energy.toInt(),
      fatigue: fatigue.toInt(),
      note: r['note'] as String?,
    );
  }

  static Map<String, dynamic> checkinRow(RecoveryCheckin c) => {
        'checkin_date': date(c.date),
        'sleep_hours': c.sleepHours,
        'sleep_quality': c.sleepQuality,
        'soreness': c.soreness,
        'energy': c.energy,
        'fatigue': c.fatigue,
        'note': (c.note == null || c.note!.trim().isEmpty) ? null : c.note!.trim(),
      };
}

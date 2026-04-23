import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Visual 30-day streak calendar. Cells are derived from the StreakInfo
/// available on the home-screen response (current, longest, lastClaimedDate):
///  - The last `current` days ending at `lastClaimedDate` are "claimed".
///  - Days before the streak start are "missed" (grey).
///  - Future days (after today) are "upcoming" (outline only).
///
/// This is a best-effort reconstruction — the backend doesn't store per-day
/// claim records, so gaps older than the current streak show as one solid
/// "missed" block rather than a day-by-day history. That matches the spec
/// intent ("visual display of login history") without adding a Mongo schema.
class StreakCalendar extends StatelessWidget {
  final int currentStreak;
  final String lastClaimedDate; // YYYY-MM-DD in IST
  final int daysToShow;

  const StreakCalendar({
    super.key,
    required this.currentStreak,
    required this.lastClaimedDate,
    this.daysToShow = 30,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastClaimed = _parseDate(lastClaimedDate);
    final streakStart = lastClaimed?.subtract(Duration(days: currentStreak - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('Login calendar — last $daysToShow days',
                style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysToShow,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) {
            // Index 0 is the oldest day; index `daysToShow-1` is today.
            final day = today.subtract(Duration(days: daysToShow - 1 - i));
            final isToday = _sameDay(day, today);
            final isClaimed = _isWithinStreak(day, streakStart, lastClaimed);

            return Container(
              decoration: BoxDecoration(
                color: isClaimed ? AppColors.gold.withAlpha(160) : AppColors.cardTint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isToday ? AppColors.accent : AppColors.border,
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isClaimed ? Colors.white : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isClaimed ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(AppColors.gold.withAlpha(160), 'Claimed'),
            const SizedBox(width: 16),
            _legendDot(AppColors.cardTint, 'Missed'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  DateTime? _parseDate(String iso) {
    if (iso.isEmpty) return null;
    try {
      final parts = iso.split('-');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWithinStreak(DateTime day, DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}

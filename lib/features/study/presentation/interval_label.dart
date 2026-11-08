import 'package:recall/features/study/domain/scheduler/scheduler.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

String intervalLabel(AppLocalizations l, Duration d) {
  final h = humanizeInterval(d);
  return switch (h.unit) {
    IntervalUnit.minutes => l.intervalMinutes(h.value),
    IntervalUnit.hours => l.intervalHours(h.value),
    IntervalUnit.days => l.intervalDays(h.value),
    IntervalUnit.months => l.intervalMonths(h.value),
    IntervalUnit.years => l.intervalYears(h.value),
  };
}

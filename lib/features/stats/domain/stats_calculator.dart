// Pure Dart: statistics derived from review history and card states.
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Reviews on one local calendar day.
class DayActivity {
  const DayActivity({
    required this.date,
    required this.reviews,
    required this.recalled,
  });

  final DateTime date;
  final int reviews;

  /// Answers that were not "Again".
  final int recalled;

  double get recallRate => reviews == 0 ? 0 : recalled / reviews;

  @override
  bool operator ==(Object other) =>
      other is DayActivity &&
      other.date == date &&
      other.reviews == reviews &&
      other.recalled == recalled;

  @override
  int get hashCode => Object.hash(date, reviews, recalled);
}

/// Everything the heatmap needs, with value equality so it can skip repaints.
class HeatmapData {
  const HeatmapData({required this.days, required this.today});

  /// Days with at least one review, keyed by local midnight.
  final Map<DateTime, DayActivity> days;
  final DateTime today;

  int get maxReviews =>
      days.values.fold(0, (m, d) => d.reviews > m ? d.reviews : m);

  @override
  bool operator ==(Object other) =>
      other is HeatmapData &&
      other.today == today &&
      other.days.length == days.length &&
      other.days.entries.every((e) => days[e.key] == e.value);

  @override
  int get hashCode => Object.hash(today, days.length, maxReviews);
}

HeatmapData buildHeatmap(List<ReviewLog> logs, DateTime now) {
  final reviews = <DateTime, int>{};
  final recalled = <DateTime, int>{};
  for (final l in logs) {
    final d = dayOf(l.reviewedAt);
    reviews[d] = (reviews[d] ?? 0) + 1;
    if (l.grade != Grade.again) recalled[d] = (recalled[d] ?? 0) + 1;
  }
  return HeatmapData(
    today: dayOf(now),
    days: {
      for (final e in reviews.entries)
        e.key: DayActivity(
          date: e.key,
          reviews: e.value,
          recalled: recalled[e.key] ?? 0,
        ),
    },
  );
}

/// Consecutive days with a review, ending today. A day without a review yet
/// does not break the streak until it is over.
int currentStreak(HeatmapData h) {
  var day = h.today;
  if (!h.days.containsKey(day)) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var n = 0;
  while (h.days.containsKey(day)) {
    n++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}

class RetentionPoint {
  const RetentionPoint({
    required this.label,
    required this.retention,
    required this.count,
  });

  /// Interval bucket label, for example "8–14".
  final String label;

  /// 0..1
  final double retention;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is RetentionPoint &&
      other.label == label &&
      other.retention == retention &&
      other.count == count;

  @override
  int get hashCode => Object.hash(label, retention, count);
}

const _buckets = <(int, int, String)>[
  (0, 1, '1'),
  (2, 3, '2–3'),
  (4, 7, '4–7'),
  (8, 14, '8–14'),
  (15, 30, '15–30'),
  (31, 60, '31–60'),
  (61, 120, '61–120'),
  (121, 1 << 30, '120+'),
];

/// Share of review-phase answers that were not "Again", grouped by the
/// interval the card had before the review. Buckets with no data are omitted.
List<RetentionPoint> retentionCurve(List<ReviewLog> logs) {
  final total = List.filled(_buckets.length, 0);
  final ok = List.filled(_buckets.length, 0);
  for (final l in logs) {
    if (l.phaseBefore != Phase.review) continue;
    for (var i = 0; i < _buckets.length; i++) {
      if (l.intervalBefore >= _buckets[i].$1 &&
          l.intervalBefore <= _buckets[i].$2) {
        total[i]++;
        if (l.grade != Grade.again) ok[i]++;
        break;
      }
    }
  }
  return [
    for (var i = 0; i < _buckets.length; i++)
      if (total[i] > 0)
        RetentionPoint(
          label: _buckets[i].$3,
          retention: ok[i] / total[i],
          count: total[i],
        ),
  ];
}

class MaturityBreakdown {
  const MaturityBreakdown({
    required this.fresh,
    required this.learning,
    required this.young,
    required this.mature,
  });

  final int fresh;
  final int learning;
  final int young;
  final int mature;

  int get total => fresh + learning + young + mature;

  @override
  bool operator ==(Object other) =>
      other is MaturityBreakdown &&
      other.fresh == fresh &&
      other.learning == learning &&
      other.young == young &&
      other.mature == mature;

  @override
  int get hashCode => Object.hash(fresh, learning, young, mature);
}

const matureThresholdDays = 21;

MaturityBreakdown maturity(List<CardState> states) {
  var f = 0;
  var l = 0;
  var y = 0;
  var m = 0;
  for (final s in states) {
    switch (s.phase) {
      case Phase.newCard:
        f++;
      case Phase.learning || Phase.relearning:
        l++;
      case Phase.review:
        s.intervalDays >= matureThresholdDays ? m++ : y++;
    }
  }
  return MaturityBreakdown(fresh: f, learning: l, young: y, mature: m);
}

/// Cards that come due today (including overdue and learning) and tomorrow.
({int today, int tomorrow}) dueForecast(List<CardState> states, DateTime now) {
  final startTomorrow = DateTime(now.year, now.month, now.day + 1);
  final startAfter = DateTime(now.year, now.month, now.day + 2);
  var today = 0;
  var tomorrow = 0;
  for (final s in states) {
    if (s.phase == Phase.newCard) continue;
    if (s.due.isBefore(startTomorrow)) {
      today++;
    } else if (s.due.isBefore(startAfter)) {
      tomorrow++;
    }
  }
  return (today: today, tomorrow: tomorrow);
}

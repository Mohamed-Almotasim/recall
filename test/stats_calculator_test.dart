import 'package:flutter_test/flutter_test.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/stats/domain/stats_calculator.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

final now = DateTime(2026, 3, 10, 15);

ReviewLog log(
  DateTime at, {
  Grade grade = Grade.good,
  Phase phase = Phase.review,
  int before = 5,
}) => ReviewLog(
  cardId: 1,
  deckId: 1,
  reviewedAt: at,
  grade: grade,
  phaseBefore: phase,
  intervalBefore: before,
  intervalAfter: before + 1,
  easeAfter: 2.5,
  elapsedDays: 0,
  durationMs: 1000,
);

DateTime daysAgo(int n, [int hour = 10]) =>
    DateTime(now.year, now.month, now.day - n, hour);

CardState state(Phase p, {int ivl = 0, DateTime? due}) => CardState(
  phase: p,
  stepIndex: 0,
  ease: 2.5,
  intervalDays: ivl,
  reps: 1,
  lapses: 0,
  due: due ?? now,
);

void main() {
  group('heatmap', () {
    test('groups by local day and counts recalled', () {
      final h = buildHeatmap([
        log(daysAgo(0, 9)),
        log(daysAgo(0, 23), grade: Grade.again),
        log(daysAgo(3)),
      ], now);
      expect(h.days[daysAgo(0, 0)]!.reviews, 2);
      expect(h.days[daysAgo(0, 0)]!.recalled, 1);
      expect(h.days[daysAgo(0, 0)]!.recallRate, 0.5);
      expect(h.days.length, 2);
      expect(h.maxReviews, 2);
    });

    test('equal data compares equal (drives shouldRepaint)', () {
      final a = buildHeatmap([log(daysAgo(1))], now);
      final b = buildHeatmap([log(daysAgo(1))], now);
      final c = buildHeatmap([log(daysAgo(1)), log(daysAgo(1))], now);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('streak', () {
    int streak(List<ReviewLog> l) => currentStreak(buildHeatmap(l, now));

    test('no reviews', () => expect(streak([]), 0));
    test('today only', () => expect(streak([log(daysAgo(0))]), 1));
    test('does not break before today is over', () {
      expect(streak([log(daysAgo(1)), log(daysAgo(2))]), 2);
    });
    test('counts consecutive days', () {
      expect(streak([log(daysAgo(0)), log(daysAgo(1)), log(daysAgo(2))]), 3);
    });
    test('a gap resets it', () {
      expect(streak([log(daysAgo(0)), log(daysAgo(2)), log(daysAgo(3))]), 1);
    });
    test('missing yesterday and today gives zero', () {
      expect(streak([log(daysAgo(2))]), 0);
    });
  });

  group('retention', () {
    test('ignores learning phase and buckets by interval', () {
      final pts = retentionCurve([
        log(daysAgo(1), phase: Phase.learning, before: 0),
        log(daysAgo(1), before: 1),
        log(daysAgo(1), before: 1, grade: Grade.again),
        log(daysAgo(1), before: 10),
        log(daysAgo(1), before: 12, grade: Grade.hard),
        log(daysAgo(1), before: 200),
      ]);
      expect([for (final p in pts) p.label], ['1', '8–14', '120+']);
      expect(pts[0].retention, 0.5);
      expect(pts[0].count, 2);
      expect(pts[1].retention, 1);
    });

    test('empty when there is no review-phase history', () {
      expect(retentionCurve([log(daysAgo(0), phase: Phase.newCard)]), isEmpty);
    });
  });

  group('maturity and forecast', () {
    final states = [
      state(Phase.newCard),
      state(Phase.newCard),
      state(Phase.learning, due: now.add(const Duration(minutes: 5))),
      state(Phase.relearning, due: now.add(const Duration(minutes: 5))),
      state(Phase.review, ivl: 20, due: now.add(const Duration(days: 20))),
      state(Phase.review, ivl: 21, due: now.add(const Duration(days: 21))),
      state(Phase.review, ivl: 3, due: DateTime(2026, 3, 11, 8)), // tomorrow
      state(Phase.review, ivl: 3, due: DateTime(2026, 3, 8)), // overdue
    ];

    test('breakdown uses the 21 day boundary', () {
      final m = maturity(states);
      expect((m.fresh, m.learning, m.young, m.mature), (2, 2, 3, 1));
      expect(m.total, 8);
    });

    test('due today includes overdue and learning; tomorrow excludes new', () {
      final f = dueForecast(states, now);
      expect(f.today, 3);
      expect(f.tomorrow, 1);
    });
  });
}

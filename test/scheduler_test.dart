import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/scheduler/scheduler.dart';

final t0 = DateTime(2026, 3, 10, 9);
const min = Duration(minutes: 1);

CardState review({
  int ivl = 10,
  double ease = 2.5,
  int lapses = 0,
  DateTime? due,
}) => CardState(
  phase: Phase.review,
  stepIndex: 0,
  ease: ease,
  intervalDays: ivl,
  reps: 5,
  lapses: lapses,
  due: due ?? t0,
);

CardState learning(Phase p, int step, {int ivl = 0}) => CardState(
  phase: p,
  stepIndex: step,
  ease: 2.5,
  intervalDays: ivl,
  reps: 1,
  lapses: 0,
  due: t0,
);

void main() {
  late FixedClock clock;
  late Scheduler s;
  setUp(() {
    clock = FixedClock(t0);
    s = Scheduler(clock);
  });

  group('learning steps (new / learning)', () {
    // phase, step, grade -> (phase, step, delay or days)
    final cases = <(Phase, int, Grade, Phase, int, Duration)>[
      (Phase.newCard, 0, Grade.again, Phase.learning, 0, min),
      (
        Phase.newCard,
        0,
        Grade.hard,
        Phase.learning,
        0,
        const Duration(seconds: 330),
      ),
      (Phase.newCard, 0, Grade.good, Phase.learning, 1, min * 10),
      (Phase.newCard, 0, Grade.easy, Phase.review, 0, const Duration(days: 4)),
      (Phase.learning, 0, Grade.again, Phase.learning, 0, min),
      (Phase.learning, 1, Grade.again, Phase.learning, 0, min),
      (Phase.learning, 1, Grade.hard, Phase.learning, 1, min * 10),
      (Phase.learning, 1, Grade.good, Phase.review, 0, const Duration(days: 1)),
      (Phase.learning, 1, Grade.easy, Phase.review, 0, const Duration(days: 4)),
    ];
    for (final (p, step, g, np, nstep, delay) in cases) {
      test('$p step $step + $g', () {
        final r = s.review(learning(p, step), g);
        expect(r.phase, np);
        expect(r.stepIndex, nstep);
        expect(r.due, t0.add(delay));
        expect(r.reps, 2);
        expect(r.lastReviewedAt, t0);
      });
    }

    test('graduating sets intervalDays and keeps ease', () {
      final r = s.review(learning(Phase.learning, 1), Grade.good);
      expect(r.intervalDays, 1);
      expect(r.ease, 2.5);
    });
  });

  group('review phase: table', () {
    // ivl, ease, grade -> ivl', ease'
    final cases = <(int, double, Grade, int, double)>[
      (10, 2.5, Grade.hard, 12, 2.35),
      (10, 2.5, Grade.good, 25, 2.5),
      (10, 2.5, Grade.easy, 33, 2.65),
      (1, 2.5, Grade.hard, 2, 2.35), // min +1
      (1, 1.3, Grade.good, 2, 1.3), // min +1
      (1, 2.5, Grade.good, 3, 2.5),
      (100, 1.3, Grade.hard, 120, 1.3), // ease floor
      (100, 1.3, Grade.good, 130, 1.3),
      (100, 3.0, Grade.easy, 390, 3.15),
    ];
    for (final (ivl, ease, g, nivl, nease) in cases) {
      test('ivl $ivl ease $ease $g', () {
        final r = s.review(review(ivl: ivl, ease: ease), g);
        expect(r.phase, Phase.review);
        expect(r.intervalDays, nivl);
        expect(r.ease, closeTo(nease, 1e-9));
        expect(r.due, t0.add(Duration(days: nivl)));
      });
    }

    test('hard never shrinks and stays above again', () {
      for (var i = 1; i < 400; i += 7) {
        final r = s.review(review(ivl: i), Grade.hard);
        expect(r.intervalDays, greaterThan(i));
      }
    });
  });

  group('lapses', () {
    for (final lapses in [0, 1, 5]) {
      test('again from review with $lapses lapses', () {
        final r = s.review(review(ivl: 30, lapses: lapses), Grade.again);
        expect(r.phase, Phase.relearning);
        expect(r.stepIndex, 0);
        expect(r.lapses, lapses + 1);
        expect(r.ease, closeTo(2.3, 1e-9));
        expect(r.intervalDays, 1); // factor 0 -> floor of 1 day
        expect(r.due, t0.add(min * 10));
      });
    }

    test('ease floors at 1.3 after many lapses', () {
      var st = review(ease: 1.4);
      for (var i = 0; i < 4; i++) {
        st = s.review(st, Grade.again);
        st = st.copyWith(phase: Phase.review);
      }
      expect(st.ease, 1.3);
    });

    test('lapseNewIntervalFactor keeps part of the interval', () {
      final sc = Scheduler(
        clock,
        const SchedulerConfig(lapseNewIntervalFactor: 0.5),
      );
      expect(sc.review(review(ivl: 40), Grade.again).intervalDays, 20);
    });

    test('relearning good graduates back with the kept interval', () {
      final lapsed = s.review(review(ivl: 30), Grade.again);
      final r = s.review(lapsed, Grade.good);
      expect(r.phase, Phase.review);
      expect(r.intervalDays, 1);
      expect(r.lapses, 1);
    });

    test('relearning easy adds a day', () {
      final r = s.review(learning(Phase.relearning, 0, ivl: 5), Grade.easy);
      expect(r.intervalDays, 6);
    });

    test('relearning hard with one step uses 1.5x', () {
      final r = s.review(learning(Phase.relearning, 0, ivl: 5), Grade.hard);
      expect(r.due, t0.add(min * 15));
    });
  });

  group('late reviews', () {
    test('good gains half the lateness', () {
      final st = review(due: t0.subtract(const Duration(days: 4)));
      // (10 + 4/2) * 2.5 = 30
      expect(s.review(st, Grade.good).intervalDays, 30);
    });
    test('easy gains the full lateness', () {
      final st = review(due: t0.subtract(const Duration(days: 4)));
      // (10 + 4) * 2.5 * 1.3 = 45.5 -> 46
      expect(s.review(st, Grade.easy).intervalDays, 46);
    });
    test('early review gets no bonus', () {
      final st = review(due: t0.add(const Duration(days: 3)));
      expect(s.review(st, Grade.good).intervalDays, 25);
    });
  });

  group('limits', () {
    test('max interval clamps', () {
      final sc = Scheduler(clock, const SchedulerConfig(maxIntervalDays: 50));
      final r = sc.review(review(ivl: 40), Grade.easy);
      expect(r.intervalDays, 50);
    });
  });

  group('preview', () {
    test('matches review for every grade and phase', () {
      final states = [
        CardState.fresh(t0),
        learning(Phase.learning, 1),
        learning(Phase.relearning, 0, ivl: 3),
        review(),
      ];
      for (final st in states) {
        final p = s.preview(st);
        for (final g in Grade.values) {
          expect(p[g], s.review(st, g).due.difference(t0), reason: '$st $g');
        }
      }
    });

    test('review hints are whole days', () {
      final p = s.preview(review());
      expect(p[Grade.good], const Duration(days: 25));
      expect(humanizeInterval(p[Grade.good]!).unit, IntervalUnit.days);
    });
  });

  group('humanizeInterval', () {
    final cases = <(Duration, int, IntervalUnit)>[
      (const Duration(seconds: 20), 1, IntervalUnit.minutes),
      (const Duration(minutes: 10), 10, IntervalUnit.minutes),
      (const Duration(hours: 5), 5, IntervalUnit.hours),
      (const Duration(days: 4), 4, IntervalUnit.days),
      (const Duration(days: 60), 2, IntervalUnit.months),
      (const Duration(days: 800), 2, IntervalUnit.years),
    ];
    for (final (d, v, u) in cases) {
      test('$d', () {
        final h = humanizeInterval(d);
        expect((h.value, h.unit), (v, u));
      });
    }
  });

  test('invariants hold over random histories', () {
    final rnd = math.Random(42);
    for (var seed = 0; seed < 1000; seed++) {
      var st = CardState.fresh(t0);
      for (var n = 0; n < 30; n++) {
        clock.current = st.due.add(Duration(hours: rnd.nextInt(72)));
        final g = Grade.values[rnd.nextInt(4)];
        final next = s.review(st, g);
        expect(next.ease, greaterThanOrEqualTo(1.3));
        expect(next.due.isAfter(clock.current), isTrue);
        expect(next.reps, st.reps + 1);
        if (next.phase == Phase.review) {
          expect(next.intervalDays, inInclusiveRange(1, 36500));
        }
        st = next;
      }
    }
  });
}

// Pure Dart. SM-2 with learning steps. See docs/PLAN.md section 3.
import 'dart:math' as math;

import 'package:recall/core/clock.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

class Scheduler {
  const Scheduler(this.clock, [this.config = const SchedulerConfig()]);

  final Clock clock;
  final SchedulerConfig config;

  /// Returns the state after answering [grade] right now.
  CardState review(CardState s, Grade grade) {
    final now = clock.now();
    final next = switch (s.phase) {
      Phase.newCard ||
      Phase.learning ||
      Phase.relearning => _step(s, grade, now),
      Phase.review => _review(s, grade, now),
    };
    return next.copyWith(reps: s.reps + 1, lastReviewedAt: now);
  }

  /// Delay until the next showing for every grade. Powers the button hints.
  Map<Grade, Duration> preview(CardState s) {
    final now = clock.now();
    return {for (final g in Grade.values) g: review(s, g).due.difference(now)};
  }

  // ---- learning / relearning ------------------------------------------

  CardState _step(CardState s, Grade grade, DateTime now) {
    final relearning = s.phase == Phase.relearning;
    final steps = relearning ? config.relearningSteps : config.learningSteps;
    final stay = relearning ? Phase.relearning : Phase.learning;
    final i = s.phase == Phase.newCard ? 0 : s.stepIndex;

    CardState at(int idx, Duration d) =>
        s.copyWith(phase: stay, stepIndex: idx, due: now.add(d));

    switch (grade) {
      case Grade.again:
        return at(0, steps.first);
      case Grade.hard:
        final d = steps.length == 1
            ? steps.first * 1.5
            : (i == 0 ? (steps[0] + steps[1]) ~/ 2 : steps[i]);
        return at(i, d);
      case Grade.good:
        if (i + 1 < steps.length) return at(i + 1, steps[i + 1]);
        return _graduate(
          s,
          now,
          relearning
              ? math.max(1, s.intervalDays)
              : config.graduatingIntervalDays,
        );
      case Grade.easy:
        return _graduate(
          s,
          now,
          relearning
              ? math.max(1, s.intervalDays) + 1
              : config.easyIntervalDays,
        );
    }
  }

  CardState _graduate(CardState s, DateTime now, int days) {
    final d = days.clamp(1, config.maxIntervalDays);
    return s.copyWith(
      phase: Phase.review,
      stepIndex: 0,
      intervalDays: d,
      due: now.add(Duration(days: d)),
    );
  }

  // ---- review -----------------------------------------------------------

  CardState _review(CardState s, Grade grade, DateTime now) {
    final i = s.intervalDays;
    final late = math.max(0, now.difference(s.due).inDays);
    final m = config.intervalModifier;

    double ease;
    int ivl;
    switch (grade) {
      case Grade.again:
        final e = math.max(config.minEase, s.ease - 0.20);
        final kept = math.max(1, (i * config.lapseNewIntervalFactor).round());
        return s.copyWith(
          phase: Phase.relearning,
          stepIndex: 0,
          ease: e,
          intervalDays: kept,
          lapses: s.lapses + 1,
          due: now.add(config.relearningSteps.first),
        );
      case Grade.hard:
        ease = math.max(config.minEase, s.ease - 0.15);
        ivl = math.max(i + 1, (i * config.hardMultiplier * m).round());
      case Grade.good:
        ease = s.ease;
        ivl = math.max(i + 1, ((i + late / 2) * s.ease * m).round());
      case Grade.easy:
        ease = s.ease + 0.15;
        ivl = math.max(
          i + 1,
          ((i + late) * s.ease * config.easyBonus * m).round(),
        );
    }
    ivl = ivl.clamp(1, config.maxIntervalDays);
    return s.copyWith(
      ease: ease,
      intervalDays: ivl,
      due: now.add(Duration(days: ivl)),
    );
  }
}

enum IntervalUnit { minutes, hours, days, months, years }

/// Splits a delay into a rounded value and unit for display ("4d", "10m").
({int value, IntervalUnit unit}) humanizeInterval(Duration d) {
  final minutes = d.inSeconds / 60;
  if (minutes < 60) {
    return (value: math.max(1, minutes.round()), unit: IntervalUnit.minutes);
  }
  final hours = minutes / 60;
  if (hours < 24) return (value: hours.round(), unit: IntervalUnit.hours);
  final days = hours / 24;
  if (days < 30) return (value: days.round(), unit: IntervalUnit.days);
  if (days < 365) {
    return (value: (days / 30).round(), unit: IntervalUnit.months);
  }
  return (value: (days / 365).round(), unit: IntervalUnit.years);
}

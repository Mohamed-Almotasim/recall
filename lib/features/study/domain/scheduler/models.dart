// Pure Dart: no Flutter, no packages. Scheduling value types.

enum Grade {
  again,
  hard,
  good,
  easy;

  /// Stable integer used in persistence.
  int get code => index;
  static Grade fromCode(int c) => Grade.values[c];
}

enum Phase {
  newCard,
  learning,
  review,
  relearning;

  int get code => index;
  static Phase fromCode(int c) => Phase.values[c];
}

/// Scheduling state of one card.
class CardState {
  const CardState({
    required this.phase,
    required this.stepIndex,
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.lapses,
    required this.due,
    this.lastReviewedAt,
  });

  factory CardState.fresh(DateTime now, {double ease = 2.5}) => CardState(
    phase: Phase.newCard,
    stepIndex: 0,
    ease: ease,
    intervalDays: 0,
    reps: 0,
    lapses: 0,
    due: now,
  );

  final Phase phase;
  final int stepIndex;
  final double ease;
  final int intervalDays;
  final int reps;
  final int lapses;
  final DateTime due;
  final DateTime? lastReviewedAt;

  CardState copyWith({
    Phase? phase,
    int? stepIndex,
    double? ease,
    int? intervalDays,
    int? reps,
    int? lapses,
    DateTime? due,
    DateTime? lastReviewedAt,
  }) => CardState(
    phase: phase ?? this.phase,
    stepIndex: stepIndex ?? this.stepIndex,
    ease: ease ?? this.ease,
    intervalDays: intervalDays ?? this.intervalDays,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    due: due ?? this.due,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is CardState &&
      other.phase == phase &&
      other.stepIndex == stepIndex &&
      other.ease == ease &&
      other.intervalDays == intervalDays &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.due == due &&
      other.lastReviewedAt == lastReviewedAt;

  @override
  int get hashCode => Object.hash(
    phase,
    stepIndex,
    ease,
    intervalDays,
    reps,
    lapses,
    due,
    lastReviewedAt,
  );

  @override
  String toString() =>
      'CardState($phase step=$stepIndex ease=$ease ivl=${intervalDays}d '
      'reps=$reps lapses=$lapses due=$due)';
}

class SchedulerConfig {
  const SchedulerConfig({
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.startingEase = 2.5,
    this.minEase = 1.3,
    this.easyBonus = 1.3,
    this.hardMultiplier = 1.2,
    this.intervalModifier = 1.0,
    this.lapseNewIntervalFactor = 0.0,
    this.maxIntervalDays = 36500,
  });

  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int graduatingIntervalDays;
  final int easyIntervalDays;
  final double startingEase;
  final double minEase;
  final double easyBonus;
  final double hardMultiplier;
  final double intervalModifier;
  final double lapseNewIntervalFactor;
  final int maxIntervalDays;
}

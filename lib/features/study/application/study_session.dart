import 'dart:math' as math;

import 'package:recall/app/providers.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/study_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_session.g.dart';

/// Drives one study session. Widgets only call [flip] and [grade].
@riverpod
class StudySession extends _$StudySession {
  late final Future<void> _loaded;

  /// Completes when the queue has been loaded. Handy in tests.
  Future<void> get loaded => _loaded;

  @override
  StudyState build(int deckId) {
    _loaded = Future.microtask(() => _load(deckId));
    return const StudyState.loading();
  }

  Future<void> _load(int deckId) async {
    final queue = await ref.read(studyRepositoryProvider).loadQueue(deckId);
    if (!ref.mounted) return;
    final now = ref.read(clockProvider).now();
    if (queue.isEmpty) {
      state = const StudyState.finished(
        summary: SessionSummary(
          reviewed: 0,
          gradeCounts: {},
          duration: Duration.zero,
        ),
      );
      return;
    }
    state = StudyState.showingFront(
      data: _present(
        card: queue.first,
        rest: queue.sublist(1),
        total: queue.length,
        completed: 0,
        counts: {for (final g in Grade.values) g: 0},
        startedAt: now,
      ),
    );
  }

  SessionData _present({
    required StudyCard card,
    required List<StudyCard> rest,
    required int total,
    required int completed,
    required Map<Grade, int> counts,
    required DateTime startedAt,
  }) => SessionData(
    current: card,
    queue: rest,
    totalCards: total,
    completedCards: completed,
    gradeCounts: counts,
    preview: ref.read(schedulerProvider).preview(card.state),
    shownAt: ref.read(clockProvider).now(),
    startedAt: startedAt,
  );

  /// Turns the card over. Allowed both ways so you can peek at the question.
  void flip() {
    switch (state) {
      case ShowingFront(:final data):
        state = StudyState.showingBack(data: data);
      case ShowingBack(:final data):
        state = StudyState.showingFront(data: data.copyWith(saveFailed: false));
      case StudyLoading() || Grading() || StudyFinished():
        break;
    }
  }

  /// Records an answer. Ignored unless the answer side is showing.
  Future<void> grade(Grade g) async {
    final s = state;
    if (s is! ShowingBack) return;
    final d = s.data;
    state = StudyState.grading(data: d, grade: g);

    final clock = ref.read(clockProvider);
    final now = clock.now();
    final prev = d.current.state;
    final next = ref.read(schedulerProvider).review(prev, g);
    final log = ReviewLog(
      cardId: d.current.card.id,
      deckId: d.current.card.deckId,
      reviewedAt: now,
      grade: g,
      phaseBefore: prev.phase,
      intervalBefore: prev.intervalDays,
      intervalAfter: next.intervalDays,
      easeAfter: next.ease,
      elapsedDays: prev.phase == Phase.review
          ? math.max(0, now.difference(prev.due).inDays)
          : 0,
      durationMs: now.difference(d.shownAt).inMilliseconds,
    );

    try {
      await ref.read(studyRepositoryProvider).saveReview(next, log);
    } on Object {
      if (ref.mounted) {
        state = StudyState.showingBack(data: d.copyWith(saveFailed: true));
      }
      return;
    }
    if (!ref.mounted) return;

    final queue = [...d.queue];
    var completed = d.completedCards;
    final delay = next.due.difference(now);
    if (next.phase != Phase.review && delay < const Duration(days: 1)) {
      // Still being learned: bring it back after a few other cards.
      final pos = math.min(queue.length, math.max(2, delay.inMinutes));
      queue.insert(pos, StudyCard(card: d.current.card, state: next));
    } else {
      completed++;
    }
    final counts = {...d.gradeCounts, g: (d.gradeCounts[g] ?? 0) + 1};

    if (queue.isEmpty) {
      state = StudyState.finished(
        summary: SessionSummary(
          reviewed: counts.values.fold(0, (a, b) => a + b),
          gradeCounts: counts,
          duration: now.difference(d.startedAt),
        ),
      );
      return;
    }
    state = StudyState.showingFront(
      data: _present(
        card: queue.first,
        rest: queue.sublist(1),
        total: d.totalCards,
        completed: completed,
        counts: counts,
        startedAt: d.startedAt,
      ),
    );
  }
}

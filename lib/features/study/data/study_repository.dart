import 'package:drift/drift.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

class StudyRepository {
  StudyRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Due learning cards, then due reviews (oldest first), then new cards.
  Future<List<StudyCard>> loadQueue(
    int deckId, {
    int newLimit = 20,
    int reviewLimit = 200,
  }) async {
    final now = _clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    Future<List<StudyCard>> fetch(Expression<bool> where, int limit) async {
      final q =
          _db.select(_db.cards).join([
              innerJoin(
                _db.cardStates,
                _db.cardStates.cardId.equalsExp(_db.cards.id),
              ),
            ])
            ..where(_db.cards.deckId.equals(deckId) & where)
            ..orderBy([
              OrderingTerm.asc(_db.cardStates.due),
              OrderingTerm.asc(_db.cards.id),
            ])
            ..limit(limit);
      final rows = await q.get();
      return [for (final r in rows) _map(r)];
    }

    final s = _db.cardStates;
    final learning = await fetch(
      s.phase.isIn([Phase.learning.code, Phase.relearning.code]) &
          s.due.isSmallerOrEqualValue(now),
      reviewLimit,
    );
    final reviews = await fetch(
      s.phase.equals(Phase.review.code) & s.due.isSmallerThanValue(tomorrow),
      reviewLimit,
    );
    final fresh = await fetch(s.phase.equals(Phase.newCard.code), newLimit);
    return [...learning, ...reviews, ...fresh];
  }

  StudyCard _map(TypedResult r) {
    final c = r.readTable(_db.cards);
    final s = r.readTable(_db.cardStates);
    return StudyCard(
      card: Flashcard(
        id: c.id,
        deckId: c.deckId,
        front: c.front,
        back: c.back,
        imagePath: c.imagePath,
        createdAt: c.createdAt,
      ),
      state: CardState(
        phase: Phase.fromCode(s.phase),
        stepIndex: s.stepIndex,
        ease: s.ease,
        intervalDays: s.intervalDays,
        reps: s.reps,
        lapses: s.lapses,
        due: s.due,
        lastReviewedAt: s.lastReviewedAt,
      ),
    );
  }

  /// Persists the new state and the log row atomically.
  Future<void> saveReview(CardState next, ReviewLog log) =>
      _db.transaction(() async {
        await (_db.update(
          _db.cardStates,
        )..where((t) => t.cardId.equals(log.cardId))).write(
          CardStatesCompanion(
            phase: Value(next.phase.code),
            stepIndex: Value(next.stepIndex),
            ease: Value(next.ease),
            intervalDays: Value(next.intervalDays),
            reps: Value(next.reps),
            lapses: Value(next.lapses),
            due: Value(next.due),
            lastReviewedAt: Value(next.lastReviewedAt),
          ),
        );
        await _db
            .into(_db.reviewLogs)
            .insert(
              ReviewLogsCompanion.insert(
                cardId: log.cardId,
                deckId: log.deckId,
                reviewedAt: log.reviewedAt,
                grade: log.grade.code,
                phaseBefore: log.phaseBefore.code,
                intervalBefore: log.intervalBefore,
                intervalAfter: log.intervalAfter,
                easeAfter: log.easeAfter,
                elapsedDays: log.elapsedDays,
                durationMs: log.durationMs,
              ),
            );
      });
}

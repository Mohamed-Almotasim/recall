import 'package:drift/drift.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  /// All review logs since [since], oldest first. Stats are derived from this.
  Stream<List<ReviewLog>> watchLogs({required DateTime since}) =>
      (_db.select(_db.reviewLogs)
            ..where((t) => t.reviewedAt.isBiggerOrEqualValue(since))
            ..orderBy([(t) => OrderingTerm.asc(t.reviewedAt)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                ReviewLog(
                  cardId: r.cardId,
                  deckId: r.deckId,
                  reviewedAt: r.reviewedAt,
                  grade: Grade.fromCode(r.grade),
                  phaseBefore: Phase.fromCode(r.phaseBefore),
                  intervalBefore: r.intervalBefore,
                  intervalAfter: r.intervalAfter,
                  easeAfter: r.easeAfter,
                  elapsedDays: r.elapsedDays,
                  durationMs: r.durationMs,
                ),
            ],
          );

  /// Current scheduling state of every card (for maturity and due forecasts).
  Stream<List<CardState>> watchStates() => _db
      .select(_db.cardStates)
      .watch()
      .map(
        (rows) => [
          for (final s in rows)
            CardState(
              phase: Phase.fromCode(s.phase),
              stepIndex: s.stepIndex,
              ease: s.ease,
              intervalDays: s.intervalDays,
              reps: s.reps,
              lapses: s.lapses,
              due: s.due,
              lastReviewedAt: s.lastReviewedAt,
            ),
        ],
      );
}

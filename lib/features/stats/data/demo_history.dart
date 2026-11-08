import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

/// Fills the database with a believable year of study. Used for screenshots
/// and demos only (`--dart-define=DEMO_HISTORY=true`); never on a real profile.
Future<void> seedDemoHistory(AppDatabase db, DateTime now) async {
  final cards = await db.select(db.cards).get();
  if (cards.isEmpty) return;
  final rnd = math.Random(7);
  final today = DateTime(now.year, now.month, now.day);

  final logs = <ReviewLogsCompanion>[];
  for (var back = 0; back < 300; back++) {
    // A recent run of daily study, then a more patchy past.
    final studied = back < 12 || rnd.nextDouble() < (back < 120 ? 0.7 : 0.4);
    if (!studied) continue;
    final n = 8 + rnd.nextInt(back < 60 ? 50 : 24);
    for (var i = 0; i < n; i++) {
      final card = cards[rnd.nextInt(cards.length)];
      final ivl = math.pow(1.35, rnd.nextDouble() * 15).floor();
      final forget = 0.06 + 0.002 * ivl;
      final r = rnd.nextDouble();
      final grade = r < forget
          ? Grade.again
          : r < forget + 0.1
          ? Grade.hard
          : r < 0.88
          ? Grade.good
          : Grade.easy;
      final at = today
          .subtract(Duration(days: back))
          .add(Duration(hours: 7 + rnd.nextInt(14), minutes: rnd.nextInt(60)));
      if (at.isAfter(now)) continue;
      logs.add(
        ReviewLogsCompanion.insert(
          cardId: card.id,
          deckId: card.deckId,
          reviewedAt: at,
          grade: grade.code,
          phaseBefore: ivl <= 1 && rnd.nextDouble() < 0.4
              ? Phase.learning.code
              : Phase.review.code,
          intervalBefore: ivl,
          intervalAfter: grade == Grade.again ? 1 : (ivl * 2.2).ceil(),
          easeAfter: 2.5,
          elapsedDays: rnd.nextInt(3),
          durationMs: 2500 + rnd.nextInt(9000),
        ),
      );
    }
  }

  await db.batch((b) {
    b.insertAll(db.reviewLogs, logs);
    for (var i = 0; i < cards.length; i++) {
      // Roughly: half mature, a quarter young, the rest still new or due now.
      final k = i % 8;
      if (k >= 6) continue; // stays new
      final ivl = k < 3 ? 25 + rnd.nextInt(120) : 2 + rnd.nextInt(18);
      final dueIn = k == 5 ? -1 : (k == 4 ? 1 : 2 + rnd.nextInt(20));
      b.update(
        db.cardStates,
        CardStatesCompanion(
          phase: Value(Phase.review.code),
          intervalDays: Value(ivl),
          reps: Value(3 + rnd.nextInt(8)),
          due: Value(today.add(Duration(days: dueIn, hours: 8))),
          lastReviewedAt: Value(today.subtract(Duration(days: ivl ~/ 3))),
        ),
        where: (t) => t.cardId.equals(cards[i].id),
      );
    }
  });
}

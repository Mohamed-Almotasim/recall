import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/core/settings_repository.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/application/seed_service.dart';
import 'package:recall/features/decks/data/deck_repository.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/stats/data/stats_repository.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/study/data/study_repository.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/scheduler/scheduler.dart';

import 'seed_loader.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DeckRepository decks;
  late StudyRepository study;
  late StatsRepository stats;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 3, 10, 9));
    decks = DeckRepository(db, clock);
    study = StudyRepository(db, clock);
    stats = StatsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> deckWith(int n) => decks.createDeckWithCards(
    name: 'D',
    colorValue: 0xFF000000,
    cards: [for (var i = 0; i < n; i++) CardDraft(front: 'f$i', back: 'b$i')],
  );

  test('create, update and delete a deck', () async {
    final id = await decks.saveDeck(name: 'A', colorValue: 1, description: 'x');
    expect((await decks.getDeck(id))!.name, 'A');
    await decks.saveDeck(id: id, name: 'B', colorValue: 2, iconKey: 'code');
    final d = (await decks.getDeck(id))!;
    expect((d.name, d.colorValue, d.iconKey), ('B', 2, 'code'));
    await decks.deleteDeck(id);
    expect(await decks.getDeck(id), isNull);
  });

  test('deleting a deck cascades to cards and states', () async {
    final id = await deckWith(3);
    await decks.deleteDeck(id);
    expect(await db.select(db.cards).get(), isEmpty);
    expect(await db.select(db.cardStates).get(), isEmpty);
  });

  test('new cards get a fresh state and show in summaries', () async {
    final id = await deckWith(4);
    final cards = await decks.watchCards(id).first;
    expect(cards, hasLength(4));
    expect(cards.first.state.phase, Phase.newCard);
    final s = (await decks.watchSummaries().first).single;
    expect((s.total, s.fresh, s.due), (4, 4, 0));
  });

  test('card edit and delete', () async {
    final id = await deckWith(2);
    final first = (await decks.watchCards(id).first).first.card;
    await decks.updateCard(first.id, const CardDraft(front: 'X', back: 'Y'));
    expect((await decks.getCard(first.id))!.front, 'X');
    await decks.deleteCard(first.id);
    expect(await decks.watchCards(id).first, hasLength(1));
  });

  test('queue: learning, then due reviews, then limited new cards', () async {
    final id = await deckWith(30);
    final all = await decks.watchCards(id).first;
    final sched = Scheduler(clock);
    // card0 -> review due now; card1 -> review due in 5 days; card2 learning
    Future<void> put(int i, CardState s) => study.saveReview(
      s,
      ReviewLog(
        cardId: all[i].card.id,
        deckId: id,
        reviewedAt: clock.now(),
        grade: Grade.good,
        phaseBefore: Phase.newCard,
        intervalBefore: 0,
        intervalAfter: s.intervalDays,
        easeAfter: s.ease,
        elapsedDays: 0,
        durationMs: 1000,
      ),
    );
    await put(
      0,
      CardState.fresh(clock.now()).copyWith(
        phase: Phase.review,
        intervalDays: 3,
        due: clock.now().subtract(const Duration(hours: 1)),
      ),
    );
    await put(
      1,
      CardState.fresh(clock.now()).copyWith(
        phase: Phase.review,
        intervalDays: 3,
        due: clock.now().add(const Duration(days: 5)),
      ),
    );
    await put(
      2,
      sched.review(CardState.fresh(clock.now()), Grade.again),
    ); // learning, due in 1 minute
    clock.advance(const Duration(minutes: 2));

    final q = await study.loadQueue(id);
    final ids = q.map((c) => c.card.id).toList();
    expect(ids.first, all[2].card.id); // learning first
    expect(ids[1], all[0].card.id); // then review
    expect(ids, isNot(contains(all[1].card.id))); // not due
    expect(q.where((c) => c.state.phase == Phase.newCard), hasLength(20));
  });

  test('saveReview updates state and writes a log atomically', () async {
    final id = await deckWith(1);
    final c = (await decks.watchCards(id).first).single;
    final next = Scheduler(clock).review(c.state, Grade.easy);
    await study.saveReview(
      next,
      ReviewLog(
        cardId: c.card.id,
        deckId: id,
        reviewedAt: clock.now(),
        grade: Grade.easy,
        phaseBefore: Phase.newCard,
        intervalBefore: 0,
        intervalAfter: next.intervalDays,
        easeAfter: next.ease,
        elapsedDays: 0,
        durationMs: 800,
      ),
    );
    final after = (await decks.watchCards(id).first).single.state;
    expect(after, next);
    final logs = await stats.watchLogs(since: DateTime(2026)).first;
    expect(logs.single.grade, Grade.easy);
    expect(logs.single.intervalAfter, 4);
    final states = await stats.watchStates().first;
    expect(states.single.phase, Phase.review);
  });

  test('due counts in summaries', () async {
    final id = await deckWith(2);
    final c = (await decks.watchCards(id).first).first;
    await study.saveReview(
      c.state.copyWith(
        phase: Phase.review,
        intervalDays: 2,
        due: DateTime(2026, 3, 10, 22), // later today still counts
      ),
      ReviewLog(
        cardId: c.card.id,
        deckId: id,
        reviewedAt: clock.now(),
        grade: Grade.good,
        phaseBefore: Phase.newCard,
        intervalBefore: 0,
        intervalAfter: 2,
        easeAfter: 2.5,
        elapsedDays: 0,
        durationMs: 1,
      ),
    );
    final s = (await decks.watchSummaries().first).single;
    expect((s.due, s.fresh), (1, 1));
  });

  test('seed loads three decks once', () async {
    final settings = SettingsRepository(db);
    for (var i = 0; i < 2; i++) {
      await seedIfFirstRun(
        decks: decks,
        settings: settings,
        loadAsset: loadSeedFromDisk,
      );
    }
    final s = await decks.watchSummaries().first;
    expect(s, hasLength(3));
    expect(s.every((d) => d.total >= 10), isTrue);
  });

  test('settings round trip', () async {
    final s = SettingsRepository(db);
    await s.write('locale', 'ar');
    await s.write('locale', 'en');
    expect((await s.readAll())['locale'], 'en');
  });
}

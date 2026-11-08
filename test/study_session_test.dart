import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/study/application/study_session.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/study_state.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;
  late int deckId;

  Future<void> setUpDeck(int cards) async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 3, 10, 9));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    deckId = await container
        .read(deckRepositoryProvider)
        .createDeckWithCards(
          name: 'T',
          colorValue: 1,
          cards: [
            for (var i = 0; i < cards; i++)
              CardDraft(front: 'f$i', back: 'b$i'),
          ],
        );
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<StudySession> open() async {
    // Keep the auto-dispose provider alive for the test.
    container.listen(studySessionProvider(deckId), (_, _) {});
    final n = container.read(studySessionProvider(deckId).notifier);
    await n.loaded;
    return n;
  }

  StudyState read() => container.read(studySessionProvider(deckId));

  test('starts in loading then showingFront', () async {
    await setUpDeck(2);
    container.listen(studySessionProvider(deckId), (_, _) {});
    expect(read(), isA<StudyLoading>());
    await container.read(studySessionProvider(deckId).notifier).loaded;
    final s = read();
    expect(s, isA<ShowingFront>());
    expect((s as ShowingFront).data.totalCards, 2);
    expect(s.data.preview.keys, Grade.values);
  });

  test('empty deck finishes immediately', () async {
    await setUpDeck(0);
    await open();
    expect((read() as StudyFinished).summary.reviewed, 0);
  });

  test('flip toggles between front and back', () async {
    await setUpDeck(1);
    final n = await open();
    n.flip();
    expect(read(), isA<ShowingBack>());
    n.flip();
    expect(read(), isA<ShowingFront>());
  });

  test('grade is ignored while showing the front', () async {
    await setUpDeck(1);
    final n = await open();
    await n.grade(Grade.good);
    expect(read(), isA<ShowingFront>());
    expect(await db.select(db.reviewLogs).get(), isEmpty);
  });

  test('grading persists state and a log, then advances', () async {
    await setUpDeck(2);
    final n = await open();
    final first = (read() as ShowingFront).data.current.card.id;
    n
      ..flip()
      ..grade(Grade.easy).ignore();
    expect(read(), isA<Grading>());
    await pumpEventQueue();
    final s = read() as ShowingFront;
    expect(s.data.current.card.id, isNot(first));
    expect(s.data.completedCards, 1);
    final logs = await db.select(db.reviewLogs).get();
    expect(logs.single.grade, Grade.easy.code);
    expect(logs.single.cardId, first);
  });

  test('again re-queues the card; finishing yields a summary', () async {
    await setUpDeck(1);
    final n = await open();
    n.flip();
    await n.grade(Grade.again);
    // Same card comes back (learning step).
    final s = read() as ShowingFront;
    expect(s.data.completedCards, 0);
    expect(s.data.current.state.phase, Phase.learning);

    clock.advance(const Duration(seconds: 30));
    n.flip();
    await n.grade(Grade.easy); // graduates
    final done = read() as StudyFinished;
    expect(done.summary.reviewed, 2);
    expect(done.summary.gradeCounts[Grade.again], 1);
    expect(done.summary.gradeCounts[Grade.easy], 1);
    expect(done.summary.recallRate, 0.5);
    expect(done.summary.duration, const Duration(seconds: 30));
  });

  test('persistence failure returns to showingBack with a flag', () async {
    await setUpDeck(1);
    final n = await open();
    n.flip();
    await db.customStatement('DROP TABLE review_logs');
    await n.grade(Grade.good);
    final s = read() as ShowingBack;
    expect(s.data.saveFailed, isTrue);
  });

  test('state sequence for a full pass is exactly as designed', () async {
    await setUpDeck(1);
    final seen = <Type>[];
    container.listen(
      studySessionProvider(deckId),
      (_, next) => seen.add(next.runtimeType),
      fireImmediately: true,
    );
    final n = container.read(studySessionProvider(deckId).notifier);
    await n.loaded;
    n.flip();
    await n.grade(Grade.easy);
    expect(seen, [
      StudyLoading,
      ShowingFront,
      ShowingBack,
      Grading,
      StudyFinished,
    ]);
  });
}

import 'package:drift/drift.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

class DeckRepository {
  DeckRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Deck _toDeck(DeckRow r) => Deck(
    id: r.id,
    name: r.name,
    description: r.description,
    colorValue: r.colorValue,
    iconKey: r.iconKey,
    createdAt: r.createdAt,
  );

  Flashcard _toCard(CardRow r) => Flashcard(
    id: r.id,
    deckId: r.deckId,
    front: r.front,
    back: r.back,
    imagePath: r.imagePath,
    createdAt: r.createdAt,
  );

  CardState _toState(CardStateRow s) => CardState(
    phase: Phase.fromCode(s.phase),
    stepIndex: s.stepIndex,
    ease: s.ease,
    intervalDays: s.intervalDays,
    reps: s.reps,
    lapses: s.lapses,
    due: s.due,
    lastReviewedAt: s.lastReviewedAt,
  );

  static DateTime startOfTomorrow(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  // ---- decks -------------------------------------------------------------

  /// Decks with total / due / new counts. Re-emits when decks, cards or
  /// states change.
  Stream<List<DeckSummary>> watchSummaries() {
    final now = _clock.now();
    return _db
        .customSelect(
          '''
SELECT d.*,
  (SELECT COUNT(*) FROM cards c WHERE c.deck_id = d.id) AS total,
  (SELECT COUNT(*) FROM cards c JOIN card_states s ON s.card_id = c.id
     WHERE c.deck_id = d.id AND s.phase = 0) AS fresh,
  (SELECT COUNT(*) FROM cards c JOIN card_states s ON s.card_id = c.id
     WHERE c.deck_id = d.id AND (
       (s.phase IN (1, 3) AND s.due <= ?1) OR (s.phase = 2 AND s.due < ?2)
     )) AS due
FROM decks d ORDER BY d.created_at, d.id
''',
          variables: [
            Variable.withDateTime(now),
            Variable.withDateTime(startOfTomorrow(now)),
          ],
          readsFrom: {_db.decks, _db.cards, _db.cardStates},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              DeckSummary(
                deck: Deck(
                  id: r.read<int>('id'),
                  name: r.read<String>('name'),
                  description: r.read<String>('description'),
                  colorValue: r.read<int>('color_value'),
                  iconKey: r.read<String>('icon_key'),
                  createdAt: r.read<DateTime>('created_at'),
                ),
                total: r.read<int>('total'),
                fresh: r.read<int>('fresh'),
                due: r.read<int>('due'),
              ),
          ],
        );
  }

  Stream<Deck?> watchDeck(int id) =>
      (_db.select(_db.decks)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toDeck(r));

  Future<Deck?> getDeck(int id) async {
    final r = await (_db.select(
      _db.decks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toDeck(r);
  }

  /// Inserts when [id] is null, otherwise updates. Returns the deck id.
  Future<int> saveDeck({
    required String name,
    required int colorValue,
    int? id,
    String description = '',
    String iconKey = 'book',
  }) async {
    if (id == null) {
      final newId = await _db
          .into(_db.decks)
          .insert(
            DecksCompanion.insert(
              name: name,
              colorValue: colorValue,
              description: Value(description),
              iconKey: Value(iconKey),
              createdAt: _clock.now(),
            ),
          );
      return newId;
    }
    await (_db.update(_db.decks)..where((t) => t.id.equals(id))).write(
      DecksCompanion(
        name: Value(name),
        description: Value(description),
        colorValue: Value(colorValue),
        iconKey: Value(iconKey),
      ),
    );
    return id;
  }

  Future<void> deleteDeck(int id) async {
    await (_db.delete(_db.decks)..where((t) => t.id.equals(id))).go();
  }

  Future<int> createDeckWithCards({
    required String name,
    required int colorValue,
    required List<CardDraft> cards,
    String description = '',
    String iconKey = 'book',
  }) => _db.transaction(() async {
    final deckId = await saveDeck(
      name: name,
      colorValue: colorValue,
      description: description,
      iconKey: iconKey,
    );
    for (final c in cards) {
      await addCard(deckId, c);
    }
    return deckId;
  });

  Future<bool> hasAnyDeck() async =>
      (await (_db.select(_db.decks)..limit(1)).get()).isNotEmpty;

  // ---- cards -------------------------------------------------------------

  Stream<List<StudyCard>> watchCards(int deckId) {
    final q =
        _db.select(_db.cards).join([
            innerJoin(
              _db.cardStates,
              _db.cardStates.cardId.equalsExp(_db.cards.id),
            ),
          ])
          ..where(_db.cards.deckId.equals(deckId))
          ..orderBy([OrderingTerm.asc(_db.cards.id)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          StudyCard(
            card: _toCard(r.readTable(_db.cards)),
            state: _toState(r.readTable(_db.cardStates)),
          ),
      ],
    );
  }

  Future<Flashcard?> getCard(int id) async {
    final r = await (_db.select(
      _db.cards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toCard(r);
  }

  Future<int> addCard(int deckId, CardDraft draft) => _db.transaction(() async {
    final now = _clock.now();
    final id = await _db
        .into(_db.cards)
        .insert(
          CardsCompanion.insert(
            deckId: deckId,
            front: draft.front,
            back: draft.back,
            imagePath: Value(draft.imagePath),
            createdAt: now,
          ),
        );
    final s = CardState.fresh(now);
    await _db
        .into(_db.cardStates)
        .insert(
          CardStatesCompanion.insert(
            cardId: Value(id),
            phase: s.phase.code,
            stepIndex: s.stepIndex,
            ease: s.ease,
            intervalDays: s.intervalDays,
            reps: s.reps,
            lapses: s.lapses,
            due: s.due,
          ),
        );
    return id;
  });

  Future<void> updateCard(int id, CardDraft draft) async {
    await (_db.update(_db.cards)..where((t) => t.id.equals(id))).write(
      CardsCompanion(
        front: Value(draft.front),
        back: Value(draft.back),
        imagePath: Value(draft.imagePath),
      ),
    );
  }

  Future<void> deleteCard(int id) async {
    await (_db.delete(_db.cards)..where((t) => t.id.equals(id))).go();
  }
}

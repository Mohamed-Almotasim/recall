import 'package:flutter_test/flutter_test.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/import_export/domain/deck_json.dart';

void main() {
  final deck = Deck(
    id: 1,
    name: 'Capitals',
    description: 'd',
    colorValue: 0xFF123456,
    iconKey: 'public',
    createdAt: DateTime(2026),
  );
  Flashcard card(String f, String b) =>
      Flashcard(id: 1, deckId: 1, front: f, back: b, createdAt: DateTime(2026));

  test('round trip keeps deck fields and Arabic text', () {
    final json = encodeDeck(deck, [card('كتاب', '**book**'), card('a', 'b')]);
    final b = decodeDeck(json);
    expect(b.name, 'Capitals');
    expect(b.colorValue, 0xFF123456);
    expect(b.iconKey, 'public');
    expect(b.cards, hasLength(2));
    expect(b.cards.first.front, 'كتاب');
    expect(b.cards.first.back, '**book**');
  });

  test('rejects things that are not deck files', () {
    for (final bad in [
      'nope',
      '[]',
      '{"format":"x"}',
      '{"format":"recall.deck"}',
    ]) {
      expect(() => decodeDeck(bad), throwsFormatException, reason: bad);
    }
  });

  test('drops incomplete cards and requires a name', () {
    final b = decodeDeck(
      '{"format":"recall.deck","deck":{"name":"X"},"cards":'
      '[{"front":"a","back":"b"},{"front":"","back":"b"},{"front":"a"},3]}',
    );
    expect(b.cards, hasLength(1));
    expect(
      () =>
          decodeDeck('{"format":"recall.deck","deck":{"name":" "},"cards":[]}'),
      throwsFormatException,
    );
  });
}

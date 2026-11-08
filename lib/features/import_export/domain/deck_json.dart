import 'dart:convert';

import 'package:recall/features/decks/domain/models.dart';

const deckJsonFormat = 'recall.deck';

/// A deck and its cards, as stored in an export file or seed asset.
class DeckBundle {
  const DeckBundle({
    required this.name,
    required this.colorValue,
    required this.cards,
    this.description = '',
    this.iconKey = 'book',
  });

  final String name;
  final String description;
  final int colorValue;
  final String iconKey;
  final List<CardDraft> cards;
}

String encodeDeck(Deck deck, List<Flashcard> cards) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': deckJsonFormat,
      'version': 1,
      'deck': {
        'name': deck.name,
        'description': deck.description,
        'colorValue': deck.colorValue,
        'iconKey': deck.iconKey,
      },
      'cards': [
        for (final c in cards) {'front': c.front, 'back': c.back},
      ],
    });

/// Throws [FormatException] when [source] is not a Recall deck file.
DeckBundle decodeDeck(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException {
    throw const FormatException('Not valid JSON');
  }
  if (root is! Map<String, dynamic> || root['format'] != deckJsonFormat) {
    throw const FormatException('Not a Recall deck file');
  }
  final deck = root['deck'];
  final cards = root['cards'];
  if (deck is! Map<String, dynamic> || cards is! List<dynamic>) {
    throw const FormatException('Missing deck or cards');
  }
  final name = (deck['name'] as String?)?.trim() ?? '';
  if (name.isEmpty) throw const FormatException('Deck has no name');
  return DeckBundle(
    name: name,
    description: deck['description'] as String? ?? '',
    colorValue: deck['colorValue'] as int? ?? 0xFF1F6F5C,
    iconKey: deck['iconKey'] as String? ?? 'book',
    cards: [
      for (final c in cards)
        if (c is Map<String, dynamic> &&
            (c['front'] as String?)?.trim().isNotEmpty == true &&
            (c['back'] as String?)?.trim().isNotEmpty == true)
          CardDraft(front: c['front'] as String, back: c['back'] as String),
    ],
  );
}

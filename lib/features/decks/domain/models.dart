import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

part 'models.freezed.dart';

@freezed
abstract class Deck with _$Deck {
  const factory Deck({
    required int id,
    required String name,
    required int colorValue,
    required DateTime createdAt,
    @Default('') String description,
    @Default('book') String iconKey,
  }) = _Deck;
}

@freezed
abstract class Flashcard with _$Flashcard {
  const factory Flashcard({
    required int id,
    required int deckId,
    required String front,
    required String back,
    required DateTime createdAt,
    String? imagePath,
  }) = _Flashcard;
}

/// A card paired with its scheduling state.
@freezed
abstract class StudyCard with _$StudyCard {
  const factory StudyCard({required Flashcard card, required CardState state}) =
      _StudyCard;
}

@freezed
abstract class DeckSummary with _$DeckSummary {
  const factory DeckSummary({
    required Deck deck,
    @Default(0) int total,
    @Default(0) int due,
    @Default(0) int fresh,
  }) = _DeckSummary;
}

/// Text-only card used for seeding and import before ids exist.
@freezed
abstract class CardDraft with _$CardDraft {
  const factory CardDraft({
    required String front,
    required String back,
    String? imagePath,
  }) = _CardDraft;
}

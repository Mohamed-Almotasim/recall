import 'package:recall/app/providers.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'decks_providers.g.dart';

@riverpod
Stream<List<DeckSummary>> deckSummaries(Ref ref) =>
    ref.watch(deckRepositoryProvider).watchSummaries();

@riverpod
Stream<Deck?> deck(Ref ref, int deckId) =>
    ref.watch(deckRepositoryProvider).watchDeck(deckId);

@riverpod
Stream<List<StudyCard>> deckCards(Ref ref, int deckId) =>
    ref.watch(deckRepositoryProvider).watchCards(deckId);

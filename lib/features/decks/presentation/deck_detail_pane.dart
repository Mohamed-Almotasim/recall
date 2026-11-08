import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/text_direction.dart';
import 'package:recall/features/decks/application/decks_providers.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/decks/presentation/deck_style.dart';
import 'package:recall/features/import_export/presentation/export_sheet.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class DeckDetailPane extends ConsumerWidget {
  const DeckDetailPane({
    required this.deckId,
    super.key,
    this.showBack = false,
  });

  final int deckId;
  final bool showBack;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Deck deck,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteDeckTitle),
        content: Text(l.deleteDeckBody(deck.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(deckRepositoryProvider).deleteDeck(deck.id);
    if (context.mounted) const DecksRoute().go(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final deck = ref.watch(deckProvider(deckId)).value;
    final cards = ref.watch(deckCardsProvider(deckId)).value ?? const [];
    final summary = ref
        .watch(deckSummariesProvider)
        .value
        ?.where((s) => s.deck.id == deckId)
        .firstOrNull;
    if (deck == null) return const Scaffold();

    final due = summary?.due ?? 0;
    final fresh = summary?.fresh ?? 0;
    final canStudy = due + fresh > 0;
    final color = Color(deck.colorValue);

    return Scaffold(
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                tooltip: l.back,
                icon: const BackButtonIcon(),
                onPressed: () => const DecksRoute().go(context),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: l.exportDeck,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => showExportSheet(context, ref, deck, cards),
          ),
          IconButton(
            tooltip: l.editDeck,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => DeckEditRoute(deckId: deck.id).push<void>(context),
          ),
          IconButton(
            tooltip: l.deleteDeck,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, deck),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CardNewRoute(deckId: deck.id).push<void>(context),
        icon: const Icon(Icons.add),
        label: Text(l.addCard),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(deckIcon(deck.iconKey), color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(deck.name, style: context.text.headlineMedium),
              ),
            ],
          ),
          if (deck.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              deck.description,
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(label: l.cardsCount(cards.length)),
              _Stat(label: l.dueCount(due), emphasis: due > 0),
              _Stat(label: l.newCountLabel(fresh)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canStudy
                ? () => StudyRoute(deckId: deck.id).push<void>(context)
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.studyNow),
          ),
          if (!canStudy && cards.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.nothingDueBody,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(l.cardsSection, style: context.text.titleLarge),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l.noCardsYet, style: context.text.bodyMedium),
            ),
          for (final c in cards) _CardRow(card: c, deckId: deck.id),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: emphasis ? s.primaryContainer : s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: emphasis ? s.primary : s.outlineVariant),
      ),
      child: Text(label, style: context.text.labelMedium),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.deckId});

  final StudyCard card;
  final int deckId;

  String _stateLabel(AppLocalizations l) => switch (card.state.phase) {
    Phase.newCard => l.cardStateNew,
    Phase.learning || Phase.relearning => l.cardStateLearning,
    Phase.review =>
      card.state.intervalDays >= 21 ? l.cardStateMature : l.cardStateYoung,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final front = card.card.front;
    return InkWell(
      onTap: () => CardEditRoute(
        deckId: deckId,
        cardId: card.card.id,
      ).push<void>(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Directionality(
                textDirection:
                    detectDirection(front) ?? Directionality.of(context),
                child: Text(
                  front.replaceAll(RegExp('[*`]'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _stateLabel(l),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

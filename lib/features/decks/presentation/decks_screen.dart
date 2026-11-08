import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/widgets/stagger_in.dart';
import 'package:recall/features/decks/application/decks_providers.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/decks/presentation/deck_detail_pane.dart';
import 'package:recall/features/decks/presentation/deck_style.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

const twoPaneBreakpoint = 840.0;

/// Deck list, plus the selected deck. Side by side on wide screens.
class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key, this.deckId});

  final int? deckId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth >= twoPaneBreakpoint) {
        return Row(
          children: [
            SizedBox(width: 380, child: DeckListPane(selectedId: deckId)),
            const VerticalDivider(),
            Expanded(
              child: deckId == null
                  ? const _SelectPrompt()
                  : DeckDetailPane(key: ValueKey(deckId), deckId: deckId!),
            ),
          ],
        );
      }
      return deckId == null
          ? const DeckListPane()
          : DeckDetailPane(
              key: ValueKey(deckId),
              deckId: deckId!,
              showBack: true,
            );
    },
  );
}

class _SelectPrompt extends StatelessWidget {
  const _SelectPrompt();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        AppLocalizations.of(context).selectDeckPrompt,
        style: context.text.bodyLarge?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class DeckListPane extends ConsumerWidget {
  const DeckListPane({super.key, this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final decks = ref.watch(deckSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.decksTitle, style: context.text.headlineMedium),
        toolbarHeight: 72,
        actions: [
          IconButton(
            tooltip: l.importDeck,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => const ImportRoute().push<void>(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => const DeckNewRoute().push<void>(context),
        icon: const Icon(Icons.add),
        label: Text(l.newDeck),
      ),
      body: decks.when(
        data: (list) => list.isEmpty
            ? _Empty(l: l)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => StaggerIn(
                  key: ValueKey(list[i].deck.id),
                  index: i,
                  child: DeckTile(
                    summary: list[i],
                    selected: list[i].deck.id == selectedId,
                  ),
                ),
              ),
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.decksEmptyTitle, style: context.text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l.decksEmptyBody,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class DeckTile extends StatelessWidget {
  const DeckTile({required this.summary, required this.selected, super.key});

  final DeckSummary summary;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final deck = summary.deck;
    final color = Color(deck.colorValue);
    final scheme = context.colors;
    final due = summary.due;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => DeckRoute(deckId: deck.id).go(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(deckIcon(deck.iconKey), color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l.cardsCount(summary.total)} · '
                      '${l.newCountLabel(summary.fresh)}',
                      style: context.text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (due > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$due',
                    style: context.text.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

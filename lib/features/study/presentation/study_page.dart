import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/context_x.dart';
import 'package:recall/features/study/application/study_session.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/study_state.dart';
import 'package:recall/features/study/presentation/grade_bar.dart';
import 'package:recall/features/study/presentation/session_summary.dart';
import 'package:recall/features/study/presentation/swipe_card.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({required this.deckId, super.key});

  final int deckId;

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  final _swipe = SwipeCardController();

  StudySession get _session =>
      ref.read(studySessionProvider(widget.deckId).notifier);

  void _close() =>
      context.popOr(() => DeckRoute(deckId: widget.deckId).go(context));

  void _grade(Grade g) {
    // Keyboard / buttons: animate the card away; it calls _session.grade.
    if (ref.read(studySessionProvider(widget.deckId)) is ShowingBack) {
      _swipe.fling(g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(studySessionProvider(widget.deckId));

    ref.listen(studySessionProvider(widget.deckId), (_, next) {
      if (next is ShowingBack && next.data.saveFailed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _session.flip,
        const SingleActivator(LogicalKeyboardKey.enter): _session.flip,
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _grade(Grade.again),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _grade(Grade.hard),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _grade(Grade.good),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _grade(Grade.easy),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: switch (state) {
              StudyLoading() => const SizedBox.shrink(),
              ShowingFront(:final data) => _body(data, flipped: false),
              ShowingBack(:final data) => _body(data, flipped: true),
              Grading(:final data) => _body(data, flipped: true),
              StudyFinished(:final summary) => SessionSummaryView(
                summary: summary,
                onDone: _close,
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _body(SessionData data, {required bool flipped}) {
    final l = AppLocalizations.of(context);
    final grading = ref.watch(studySessionProvider(widget.deckId)) is Grading;
    final progress = data.totalCards == 0
        ? 0.0
        : data.completedCards / data.totalCards;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: l.closeSession,
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: context.colors.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l.sessionProgress(data.completedCards, data.totalCards),
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: SwipeCard(
                  key: ValueKey((data.current.card.id, data.shownAt)),
                  card: data.current,
                  flipped: flipped,
                  canGrade: flipped && !grading,
                  peek: data.queue.isEmpty
                      ? 0
                      : (data.queue.length == 1 ? 1 : 2),
                  controller: _swipe,
                  onFlip: _session.flip,
                  onGrade: _session.grade,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: flipped
                    ? GradeBar(
                        key: const ValueKey('grades'),
                        preview: data.preview,
                        enabled: !grading,
                        onGrade: _grade,
                      )
                    : SizedBox(
                        key: const ValueKey('reveal'),
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _session.flip,
                          child: Text(l.flipCard),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

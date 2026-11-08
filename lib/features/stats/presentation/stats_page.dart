import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/widgets/stagger_in.dart';
import 'package:recall/features/stats/application/stats_providers.dart';
import 'package:recall/features/stats/presentation/heatmap.dart';
import 'package:recall/features/stats/presentation/maturity_bar.dart';
import 'package:recall/features/stats/presentation/retention_chart.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final streak = ref.watch(streakProvider);
    final due = ref.watch(dueSoonProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.statsTitle, style: context.text.headlineMedium),
        toolbarHeight: 72,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              StaggerIn(
                index: 0,
                child: SizedBox(
                  height: 112,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Tile(
                          label: l.streakLabel,
                          value: '$streak',
                          caption: l.streakDays(streak),
                          emphasis: streak > 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Tile(label: l.dueToday, value: '${due.today}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Tile(
                          label: l.dueTomorrow,
                          value: '${due.tomorrow}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggerIn(
                index: 1,
                child: _Section(
                  title: l.maturityTitle,
                  child: MaturityBar(
                    data: ref.watch(maturityBreakdownProvider),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggerIn(
                index: 2,
                child: _Section(
                  title: l.heatmapTitle,
                  child: StudyHeatmap(data: ref.watch(heatmapProvider)),
                ),
              ),
              const SizedBox(height: 16),
              StaggerIn(
                index: 3,
                child: _Section(
                  title: l.retentionTitle,
                  subtitle: l.retentionSubtitle,
                  child: RetentionChart(points: ref.watch(retentionProvider)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    this.caption,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasis ? s.primaryContainer : s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emphasis ? s.primary : s.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: s.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(value, style: context.text.headlineMedium),
          if (caption != null)
            Text(
              caption!,
              style: context.text.labelSmall?.copyWith(
                color: s.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

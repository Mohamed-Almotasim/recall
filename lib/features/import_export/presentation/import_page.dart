import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/context_x.dart';
import 'package:recall/core/formatting.dart';
import 'package:recall/core/text_direction.dart';
import 'package:recall/features/decks/presentation/deck_style.dart';
import 'package:recall/features/import_export/application/import_controller.dart';
import 'package:recall/features/import_export/domain/csv_import.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _paste = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    _name.dispose();
    super.dispose();
  }

  ImportController get _ctl => ref.read(importControllerProvider.notifier);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickTable() async {
    final l = AppLocalizations.of(context);
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'tsv', 'txt'],
      );
      if (f == null) return;
      final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      final base = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      _paste.text = text;
      if (_name.text.isEmpty) _name.text = base;
      _ctl.setText(text, suggestedName: base);
    } on Object {
      if (mounted) _snack(l.importFileError);
    }
  }

  Future<void> _pickJson() async {
    final l = AppLocalizations.of(context);
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (f == null) return;
      final id = await _ctl.importJson(
        utf8.decode(await f.readAsBytes(), allowMalformed: true),
      );
      if (mounted) DeckRoute(deckId: id).go(context);
    } on FormatException {
      if (mounted) _snack(l.importJsonError);
    } on Object {
      if (mounted) _snack(l.importFileError);
    }
  }

  Future<void> _commit() async {
    final id = await _ctl.commit(colorValue: deckColors[1]);
    if (mounted) DeckRoute(deckId: id).go(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(importControllerProvider);
    final result = s.result;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.importTitle),
        leading: IconButton(
          tooltip: l.back,
          icon: const BackButtonIcon(),
          onPressed: () => context.popOr(() => const DecksRoute().go(context)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              TextField(
                controller: _paste,
                minLines: 5,
                maxLines: 9,
                style: context.text.bodyMedium?.copyWith(
                  fontFamily: monoFamily,
                  fontFamilyFallback: monoFallback,
                ),
                decoration: InputDecoration(hintText: l.importPasteHint),
                onChanged: _ctl.setText,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickTable,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(l.importPickFile),
                  ),
                  TextButton.icon(
                    onPressed: _pickJson,
                    icon: const Icon(Icons.data_object),
                    label: Text(l.importJsonLabel),
                  ),
                ],
              ),
              if (s.rows.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(l.importDelimiter, style: context.text.titleSmall),
                const SizedBox(height: 10),
                SegmentedButton<Delimiter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: Delimiter.comma,
                      label: Text(l.delimiterComma),
                    ),
                    ButtonSegment(
                      value: Delimiter.tab,
                      label: Text(l.delimiterTab),
                    ),
                    ButtonSegment(
                      value: Delimiter.semicolon,
                      label: Text(l.delimiterSemicolon),
                    ),
                  ],
                  selected: {s.delimiter},
                  onSelectionChanged: (v) => _ctl.setDelimiter(v.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.importFirstRowHeader),
                  value: s.hasHeader,
                  onChanged: (v) => _ctl.setHasHeader(value: v),
                ),
                const SizedBox(height: 12),
                Text(l.importMapColumns, style: context.text.titleSmall),
                const SizedBox(height: 10),
                _PreviewTable(state: s, onRole: _ctl.setRole),
                const SizedBox(height: 20),
                Text(
                  s.mapping.isValid
                      ? l.importRowsFound(result.cards.length)
                      : l.importNeedMapping,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.mapping.isValid
                        ? context.colors.primary
                        : context.colors.error,
                  ),
                ),
                if (result.skipped > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.importRowsSkipped(result.skipped),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.deckName),
                  onChanged: _ctl.setDeckName,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: s.canImport ? _commit : null,
                  child: Text(l.importAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.state, required this.onRole});

  final ImportState state;
  final void Function(int column, ColumnRole role) onRole;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cols = state.columnCount;
    final shown = state.rows.take(8).toList();
    final scheme = context.colors;
    String roleLabel(ColumnRole r) => switch (r) {
      ColumnRole.front => l.importColumnFront,
      ColumnRole.back => l.importColumnBack,
      ColumnRole.skip => l.importColumnSkip,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(170),
            border: TableBorder(
              horizontalInside: BorderSide(color: scheme.outlineVariant),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.surfaceContainer),
                children: [
                  for (var c = 0; c < cols; c++)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: DropdownButton<ColumnRole>(
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        value: state.mapping.roles[c],
                        items: [
                          for (final r in ColumnRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(
                                '${l.importColumnLabel(c + 1)} · ${roleLabel(r)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (r) {
                          if (r != null) onRole(c, r);
                        },
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < shown.length; i++)
                TableRow(
                  children: [
                    for (var c = 0; c < cols; c++)
                      _Cell(
                        text: c < shown[i].length ? shown[i][c] : '',
                        header: state.hasHeader && i == 0,
                        dimmed: state.mapping.roles[c] == ColumnRole.skip,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.text, required this.header, required this.dimmed});

  final String text;
  final bool header;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Directionality(
      textDirection: detectDirection(text) ?? Directionality.of(context),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: (header ? context.text.labelLarge : context.text.bodyMedium)
            ?.copyWith(
              color: dimmed
                  ? context.colors.onSurfaceVariant.withValues(alpha: 0.55)
                  : null,
            ),
      ),
    ),
  );
}

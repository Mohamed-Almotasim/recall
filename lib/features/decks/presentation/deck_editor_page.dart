import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/context_x.dart';
import 'package:recall/features/decks/presentation/deck_style.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class DeckEditorPage extends ConsumerStatefulWidget {
  const DeckEditorPage({super.key, this.deckId});

  final int? deckId;

  @override
  ConsumerState<DeckEditorPage> createState() => _DeckEditorPageState();
}

class _DeckEditorPageState extends ConsumerState<DeckEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  var _icon = 'book';
  int _color = deckColors.first;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    final id = widget.deckId;
    if (id == null) {
      _loaded = true;
    } else {
      unawaited(_load(id));
    }
  }

  Future<void> _load(int id) async {
    final d = await ref.read(deckRepositoryProvider).getDeck(id);
    if (d == null || !mounted) return;
    setState(() {
      _name.text = d.name;
      _desc.text = d.description;
      _icon = d.iconKey;
      _color = d.colorValue;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final id = await ref
        .read(deckRepositoryProvider)
        .saveDeck(
          id: widget.deckId,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          colorValue: _color,
          iconKey: _icon,
        );
    if (!mounted) return;
    if (widget.deckId == null) {
      DeckRoute(deckId: id).go(context);
    } else {
      context.popOr(() => DeckRoute(deckId: id).go(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckId == null ? l.newDeck : l.editDeck),
        actions: [
          TextButton(onPressed: _loaded ? _save : null, child: Text(l.save)),
          const SizedBox(width: 8),
        ],
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: widget.deckId == null,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: l.deckName),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? l.fieldRequired : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _desc,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l.deckDescription,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(l.deckIcon, style: context.text.titleSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final e in deckIcons.entries)
                            _Choice(
                              selected: _icon == e.key,
                              onTap: () => setState(() => _icon = e.key),
                              child: Icon(
                                e.value,
                                color: _icon == e.key
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(l.deckColor, style: context.text.titleSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in deckColors)
                            _Choice(
                              selected: _color == c,
                              onTap: () => setState(() => _color = c),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(c),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? s.primaryContainer : s.surfaceContainerLow,
            border: Border.all(
              color: selected ? s.primary : s.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

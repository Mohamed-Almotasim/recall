import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/context_x.dart';
import 'package:recall/core/markdown_lite.dart';
import 'package:recall/core/text_direction.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class CardEditorPage extends ConsumerStatefulWidget {
  const CardEditorPage({required this.deckId, super.key, this.cardId});

  final int deckId;
  final int? cardId;

  @override
  ConsumerState<CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends ConsumerState<CardEditorPage> {
  final _form = GlobalKey<FormState>();
  final _front = TextEditingController();
  final _back = TextEditingController();
  String? _image;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    final id = widget.cardId;
    if (id == null) {
      _loaded = true;
    } else {
      unawaited(_load(id));
    }
    _front.addListener(_refresh);
    _back.addListener(_refresh);
  }

  Future<void> _load(int id) async {
    final c = await ref.read(deckRepositoryProvider).getCard(id);
    if (c == null || !mounted) return;
    setState(() {
      _front.text = c.front;
      _back.text = c.back;
      _image = c.imagePath;
      _loaded = true;
    });
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  void _close() =>
      context.popOr(() => DeckRoute(deckId: widget.deckId).go(context));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final draft = CardDraft(
      front: _front.text.trim(),
      back: _back.text.trim(),
      imagePath: _image,
    );
    final repo = ref.read(deckRepositoryProvider);
    if (widget.cardId == null) {
      await repo.addCard(widget.deckId, draft);
    } else {
      await repo.updateCard(widget.cardId!, draft);
    }
    if (mounted) _close();
  }

  Future<void> _delete() async {
    await ref.read(deckRepositoryProvider).deleteCard(widget.cardId!);
    if (mounted) _close();
  }

  Future<void> _pickImage() async {
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f == null) return;
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/card_images',
    );
    await dir.create(recursive: true);
    final dest = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}',
    );
    await dest.writeAsBytes(await f.readAsBytes());
    if (mounted) setState(() => _image = dest.path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? l.addCard : l.editCard),
        actions: [
          if (widget.cardId != null)
            IconButton(
              tooltip: l.deleteCard,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _loaded ? _save : null, child: Text(l.save)),
          const SizedBox(width: 8),
        ],
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _SideField(
                        label: l.cardFront,
                        controller: _front,
                        required: l.fieldRequired,
                      ),
                      const SizedBox(height: 20),
                      _SideField(
                        label: l.cardBack,
                        controller: _back,
                        required: l.fieldRequired,
                      ),
                      const SizedBox(height: 20),
                      if (!kIsWeb)
                        _ImageField(
                          path: _image,
                          onPick: _pickImage,
                          onRemove: () => setState(() => _image = null),
                        ),
                      const SizedBox(height: 20),
                      Text(l.preview, style: context.text.titleSmall),
                      const SizedBox(height: 8),
                      _Preview(front: _front.text, back: _back.text),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SideField extends StatelessWidget {
  const _SideField({
    required this.label,
    required this.controller,
    required this.required,
  });

  final String label;
  final TextEditingController controller;
  final String required;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleSmall)),
            for (final (tip, icon, mark) in [
              (l.formatBold, Icons.format_bold, '**'),
              (l.formatItalic, Icons.format_italic, '*'),
              (l.formatCode, Icons.code, '`'),
            ])
              IconButton(
                tooltip: tip,
                icon: Icon(icon, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    controller.value = wrapSelection(controller.value, mark),
              ),
          ],
        ),
        TextFormField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          textDirection: detectDirection(controller.text),
          validator: (v) => (v ?? '').trim().isEmpty ? required : null,
        ),
      ],
    );
  }
}

class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (path == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.image_outlined),
          label: Text(l.addImage),
        ),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path!),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.close),
          label: Text(l.removeImage),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.front, required this.back});

  final String front;
  final String back;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.paper.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.outlineVariant),
    ),
    child: Column(
      children: [
        MarkdownText(front, style: context.text.titleLarge),
        const Divider(height: 28),
        MarkdownText(back, style: context.text.bodyLarge),
      ],
    ),
  );
}

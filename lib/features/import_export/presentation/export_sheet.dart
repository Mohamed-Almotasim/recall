import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/import_export/domain/deck_json.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

Future<void> showExportSheet(
  BuildContext context,
  WidgetRef ref,
  Deck deck,
  List<StudyCard> cards,
) {
  final json = encodeDeck(deck, [for (final c in cards) c.card]);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      final messenger = ScaffoldMessenger.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.exportShareTitle, style: ctx.text.titleLarge),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save_alt),
                label: Text(l.exportSave),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final saved = await FilePicker.saveFile(
                      fileName: '${deck.name}.recall.json',
                      bytes: Uint8List.fromList(utf8.encode(json)),
                      mimeType: 'application/json',
                    );
                    if (saved != null) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.exportSaved)),
                      );
                    }
                  } on Object {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.exportFailed)),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l.exportCopy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(content: Text(l.exportCopied)),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:recall/core/settings_repository.dart';
import 'package:recall/features/decks/data/deck_repository.dart';
import 'package:recall/features/import_export/domain/deck_json.dart';

const seedAssets = [
  'assets/seed/flutter_widgets.json',
  'assets/seed/arabic_english.json',
  'assets/seed/world_capitals.json',
];

const _seededKey = 'seeded';

/// Loads the demo decks once, on first run. Returns true when it seeded.
Future<bool> seedIfFirstRun({
  required DeckRepository decks,
  required SettingsRepository settings,
  required Future<String> Function(String path) loadAsset,
}) async {
  if ((await settings.readAll()).containsKey(_seededKey)) return false;
  for (final path in seedAssets) {
    final b = decodeDeck(await loadAsset(path));
    await decks.createDeckWithCards(
      name: b.name,
      description: b.description,
      colorValue: b.colorValue,
      iconKey: b.iconKey,
      cards: b.cards,
    );
  }
  await settings.write(_seededKey, '1');
  return true;
}

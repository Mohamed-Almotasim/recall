// Renders the main screens headlessly at 390x844 in en/ar x light/dark and
// writes PNGs to docs/screenshots. Run with:
//   flutter test tool/screenshots_test.dart
// Limit the run with SHOTS=en-light (language-theme) or SHOTS=tablet,
// and SCREENS=stats,decks.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/app/app.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/core/settings_repository.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/application/seed_service.dart';
import 'package:recall/features/decks/data/deck_repository.dart';
import 'package:recall/features/stats/data/demo_history.dart';
import 'package:recall/features/study/presentation/swipe_card.dart';

final _now = DateTime(2026, 11, 8, 10);
const _outDir = 'docs/screenshots';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  // Icons render as boxes in tests unless the font is loaded explicitly.
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();

  await load('Fraunces', ['Fraunces.ttf']);
  await load('SourceSans3', ['SourceSans3.ttf']);
  await load('PlexArabic', [
    'IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic-SemiBold.ttf',
  ]);
}

typedef _Act = Future<void> Function(WidgetTester t);

Future<void> _pumpFor(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pump(Duration(milliseconds: ms ~/ 4));
  }
}

Future<void> _revealCard(WidgetTester t) async {
  await t.tap(find.byType(FilledButton));
  await _pumpFor(t, 1200);
}

Future<void> _dragCard(WidgetTester t) async {
  await _revealCard(t);
  final card = find
      .descendant(
        of: find.byType(SwipeCard),
        matching: find.byType(GestureDetector),
      )
      .first;
  final g = await t.startGesture(t.getCenter(card));
  await g.moveBy(const Offset(40, -4));
  await g.moveBy(const Offset(110, -10));
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> _shoot(
  WidgetTester tester, {
  required String file,
  required String route,
  required String lang,
  required String theme,
  required Size size,
  _Act? act,
  bool settleAfter = true,
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  final clock = FixedClock(_now);
  final settings = SettingsRepository(db);
  await tester.runAsync(() async {
    await seedIfFirstRun(
      decks: DeckRepository(db, clock),
      settings: settings,
      loadAsset: (p) => File(p).readAsString(),
    );
    await seedDemoHistory(db, _now);
    await settings.write('locale', lang);
    await settings.write('theme', theme);
  });

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: RecallApp(showSplash: false, initialLocation: route),
      ),
    ),
  );
  await _pumpFor(tester, 1500);
  await act?.call(tester);
  // Keep a held drag held: only settle the other screens.
  if (settleAfter) await _pumpFor(tester, 1500);

  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$file.png').writeAsBytesSync(data!.buffer.asUint8List());
  });

  // Dispose the tree and flush drift's stream-cleanup timers.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(db.close);
}

void main() {
  final shotsFilter = Platform.environment['SHOTS'];
  final screensFilter = Platform.environment['SCREENS']?.split(',');

  setUpAll(_loadFonts);
  // No keyboard focus rings in pointer-driven screenshots.
  setUp(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch,
  );

  final screens = <String, (String, _Act?)>{
    'decks': ('/', null),
    'deck': ('/decks/1', null),
    'study-front': ('/decks/1/study', null),
    'study-back': ('/decks/1/study', _revealCard),
    'study-swipe': ('/decks/1/study', _dragCard),
    'stats': ('/stats', null),
    'settings': ('/settings', null),
    'import': ('/import', null),
  };

  const phone = Size(390, 844);
  for (final lang in ['en', 'ar']) {
    for (final theme in ['light', 'dark']) {
      final tag = '$lang-$theme';
      if (shotsFilter != null && shotsFilter != tag) continue;
      for (final e in screens.entries) {
        if (screensFilter != null && !screensFilter.contains(e.key)) continue;
        testWidgets(
          '$tag ${e.key}',
          (tester) => _shoot(
            tester,
            file: '$tag-${e.key}',
            route: e.value.$1,
            lang: lang,
            theme: theme,
            size: phone,
            act: e.value.$2,
            settleAfter: e.key != 'study-swipe',
          ),
        );
      }
    }
  }

  // Wide layouts: deck list + detail side by side, centred study card.
  if (shotsFilter == null || shotsFilter == 'tablet') {
    testWidgets(
      'tablet deck',
      (tester) => _shoot(
        tester,
        file: 'tablet-en-light-deck',
        route: '/decks/1',
        lang: 'en',
        theme: 'light',
        size: const Size(1024, 700),
      ),
    );
    testWidgets(
      'tablet study',
      (tester) => _shoot(
        tester,
        file: 'tablet-en-light-study',
        route: '/decks/1/study',
        lang: 'en',
        theme: 'light',
        size: const Size(1024, 700),
        act: _revealCard,
      ),
    );
  }
}

// End to end: import a deck -> study -> grade -> stats update.
// Run on a device:   flutter test integration_test
// (Uses an in-memory database so the run never touches real data.)
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recall/app/app.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/core/settings_repository.dart';
import 'package:recall/data/database/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import a deck, study it, and see the stats change', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    // Mark the demo decks as already seeded so the list starts empty.
    await tester.runAsync(() => SettingsRepository(db).write('seeded', '1'));

    Future<void> settle([int ms = 600]) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(Duration(milliseconds: ms ~/ 4));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const RecallApp(showSplash: false),
      ),
    );
    await settle();
    expect(find.text('No decks yet'), findsOneWidget);

    // Import from pasted CSV.
    await tester.tap(find.byTooltip('Import deck'));
    await settle();
    await tester.enterText(
      find.byType(TextField).first,
      'Question,Answer\nCapital of France,Paris\nCapital of Italy,Rome',
    );
    await settle();
    expect(find.text('2 cards ready to import'), findsOneWidget);
    // The name field and button sit below the fold of a lazy list.
    final scroll = find.byType(Scrollable).first;
    final nameField = find.widgetWithText(TextField, 'Name');
    await tester.scrollUntilVisible(nameField, 200, scrollable: scroll);
    await tester.enterText(nameField, 'Capitals');
    await settle();
    final importButton = find.widgetWithText(FilledButton, 'Import');
    await tester.scrollUntilVisible(importButton, 200, scrollable: scroll);
    await tester.tap(importButton);
    await settle(900);

    // Deck detail, then study.
    await settle(1200);
    expect(find.text('Capitals'), findsWidgets);
    expect(find.text('2 cards'), findsOneWidget);
    await tester.tap(find.text('Study now'));
    await settle(900);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Reveal answer'));
      await settle(1000);
      await tester.tap(find.text('Easy'));
      await settle(1500);
    }
    expect(find.text('Session complete'), findsOneWidget);
    await settle(2400); // the ring counts up to the recall rate
    expect(find.text('100%'), findsOneWidget);

    // Back to the deck, then the stats tab.
    await tester.tap(find.text('Back to deck'));
    await settle(900);
    await tester.tap(find.text('Stats'));
    await settle(1200);
    expect(find.text('1 day'), findsOneWidget); // streak
    expect(find.text('Study activity'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  });
}

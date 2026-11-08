import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/clock.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/presentation/grade_style.dart';
import 'package:recall/features/study/presentation/study_page.dart';
import 'package:recall/features/study/presentation/swipe_card.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

void main() {
  late AppDatabase db;

  Future<void> pumpStudy(WidgetTester tester, {int cards = 3}) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FixedClock(DateTime(2026, 3, 10, 9));
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    final deckId = (await tester.runAsync(
      () => container
          .read(deckRepositoryProvider)
          .createDeckWithCards(
            name: 'T',
            colorValue: 1,
            cards: [
              for (var i = 0; i < cards; i++)
                CardDraft(front: 'front $i', back: 'back $i'),
            ],
          ),
    ))!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(const Locale('en')),
          home: StudyPage(deckId: deckId),
        ),
      ),
    );
    // Let the queue load.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> reveal(WidgetTester tester) async {
    await tester.tap(find.text('Reveal answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<List<ReviewLogRow>> logs(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.reviewLogs).get()))!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('gradeForOffset', () {
    final table = <(Offset, Grade)>[
      (const Offset(-80, 10), Grade.again),
      (const Offset(80, -10), Grade.good),
      (const Offset(5, -90), Grade.hard),
      (const Offset(-5, 90), Grade.easy),
    ];
    for (final (o, g) in table) {
      test('$o -> $g', () => expect(gradeForOffset(o), g));
    }
  });

  group('swipe grading', () {
    final cases = <(String, Offset, Grade)>[
      ('left', const Offset(-320, 0), Grade.again),
      ('up', const Offset(0, -320), Grade.hard),
      ('right', const Offset(320, 0), Grade.good),
      ('down', const Offset(0, 320), Grade.easy),
    ];
    for (final (name, delta, grade) in cases) {
      testWidgets('swipe $name grades ${grade.name}', (tester) async {
        await pumpStudy(tester);
        await reveal(tester);
        await tester.fling(find.byType(SwipeCard), delta, 1800);
        await settle(tester);
        final l = await logs(tester);
        expect(l, hasLength(1));
        expect(l.single.grade, grade.code);
      });
    }

    testWidgets('a short drag springs back without grading', (tester) async {
      await pumpStudy(tester);
      await reveal(tester);
      // The widget's own box never moves; the card inside it does.
      final card = find
          .descendant(
            of: find.byType(SwipeCard),
            matching: find.byType(GestureDetector),
          )
          .first;
      final before = tester.getCenter(card);
      final g = await tester.startGesture(before);
      await g.moveBy(const Offset(30, 0)); // crosses the touch slop
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(tester.getCenter(card).dx, greaterThan(before.dx + 20));
      await g.up();
      await settle(tester);
      expect((tester.getCenter(card) - before).distance, lessThan(1));
      expect(await logs(tester), isEmpty);
    });

    testWidgets('cannot swipe before the answer is revealed', (tester) async {
      await pumpStudy(tester);
      await tester.fling(find.byType(SwipeCard), const Offset(320, 0), 1800);
      await settle(tester);
      expect(await logs(tester), isEmpty);
    });
  });

  group('button and keyboard alternatives', () {
    testWidgets('grade buttons show interval hints and grade', (tester) async {
      await pumpStudy(tester);
      await reveal(tester);
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('1m'), findsOneWidget); // again on a new card
      expect(find.text('4d'), findsOneWidget); // easy on a new card
      await tester.tap(find.text('Good'));
      await settle(tester);
      final l = await logs(tester);
      expect(l.single.grade, Grade.good.code);
    });

    testWidgets('space flips and 4 grades easy', (tester) async {
      await pumpStudy(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Good'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await settle(tester);
      expect((await logs(tester)).single.grade, Grade.easy.code);
    });

    testWidgets('finishing the last card shows the summary', (tester) async {
      await pumpStudy(tester, cards: 1);
      await reveal(tester);
      await tester.tap(find.text('Easy'));
      await settle(tester);
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Back to deck'), findsOneWidget);
    });
  });
}

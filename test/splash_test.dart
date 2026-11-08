import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/splash/recall_splash.dart';

void main() {
  testWidgets('plays through and reports completion once', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: RecallSplash(onFinished: () => done++)),
    );
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, 1);
  });

  testWidgets('reduced motion skips straight to the end frame', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: RecallSplash(onFinished: () => done++)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(done, 1);
  });

  testWidgets('has no dependency on app theme or localisation', (tester) async {
    // Pumped without MaterialApp: only Directionality and MediaQuery.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(),
          child: SizedBox(width: 400, height: 800, child: _Host()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RecallSplash), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => RecallSplash(onFinished: () {});
}

// Writes a contact sheet of splash frames to docs/screenshots/splash-frames.png
//   flutter test tool/splash_frames_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/splash/recall_splash.dart';

void main() {
  testWidgets('splash contact sheet', (tester) async {
    const times = [150, 600, 1000, 1350, 1700, 2000, 2400, 2800];
    final key = GlobalKey();
    tester.view
      ..physicalSize = const Size(260, 380)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final frames = <ui.Image>[];
    for (final ms in times) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: RecallSplash(onFinished: () {}, key: ValueKey(ms)),
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: ms));
      await tester.runAsync(() async {
        final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        frames.add(await b.toImage());
      });
    }
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const w = 260.0;
      const h = 380.0;
      for (var i = 0; i < frames.length; i++) {
        c.drawImage(frames[i], Offset((i % 4) * w, (i ~/ 4) * h), Paint());
      }
      final img = await rec.endRecording().toImage(1040, 760);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/screenshots').createSync(recursive: true);
      File('docs/screenshots/splash-frames.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });
}

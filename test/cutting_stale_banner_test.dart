// vdd-comics-editor-ai-uiux, follow-up: the stale banner renders on CuttingCanvas's results view
// once EditorController.refreshCuttingStaleness flags the session, and its Dismiss button clears
// it. Re-run's real re-stitch/re-trigger path is already covered logically by
// cutting_stale_test.dart + cutting_canvas_test.dart's own trigger coverage; this focuses on the
// banner's own visibility and Dismiss wiring.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/widgets/cutting_canvas.dart';

Uint8List _samplePng([int width = 40, int height = 30]) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 60; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  await tester.pump();
}

Widget _host(EditorController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 500,
        height: 500,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CuttingCanvas(
            controller: controller,
            selectedRegionIndex: null,
            onSelectRegion: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('no banner while the session is fresh', (tester) async {
    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });
    controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero, regions: [
      DetectedRegion(
        kind: 'character',
        confidence: 0.9,
        bbox: const Rect.fromLTWH(0, 0, 40, 30),
        cropPng: _samplePng(),
      ),
    ]);
    await tester.runAsync(() async {
      controller.triggerCutting(_samplePng(), 0);
    });
    await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);

    await tester.pumpWidget(_host(controller));
    await tester.pump(); // let the post-frame staleness check run once

    expect(find.textContaining('Source image changed'), findsNothing);
  });

  testWidgets('banner appears once flagged stale, and Dismiss clears it', (tester) async {
    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });
    controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero, regions: [
      DetectedRegion(
        kind: 'character',
        confidence: 0.9,
        bbox: const Rect.fromLTWH(0, 0, 40, 30),
        cropPng: _samplePng(),
      ),
    ]);
    await tester.runAsync(() async {
      controller.triggerCutting(_samplePng(), 0);
    });
    await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);

    controller.selectLayer(0);
    await tester.runAsync(() async {
      await controller.setImageFile('en', _samplePng(999, 777));
    });

    await tester.pumpWidget(_host(controller));
    await tester.pump(); // triggers the post-frame staleness check
    await tester.pump(); // rebuild reflecting the now-stale session

    expect(find.textContaining('Source image changed'), findsOneWidget);
    expect(controller.cuttingSession!.stale, isTrue);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(controller.cuttingSession!.stale, isFalse);
    expect(find.textContaining('Source image changed'), findsNothing);
  });
}

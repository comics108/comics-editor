// vdd-comics-editor-ai-uiux (follow-up): the results canvas's zoom control -- +/- buttons change
// the displayed percentage, Fit resets to 100%, mirroring canvas_view.dart's own _ZoomControl
// behavior for the Edit-mode canvas.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/cutting_canvas.dart';

Uint8List _samplePng([int width = 200, int height = 150]) =>
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

Future<EditorController> _controllerWithResults(WidgetTester tester) async {
  final controller = EditorController()..newDoc(DocType.comics);
  controller.cuttingClient = StubCuttingClient(
    stepDelay: Duration.zero,
    regions: [
      DetectedRegion(
        kind: 'character',
        confidence: 0.9,
        bbox: const Rect.fromLTWH(0, 0, 50, 40),
        cropPng: _samplePng(50, 40),
      ),
    ],
  );
  await tester.runAsync(() async {
    controller.triggerCutting(_samplePng(), 0);
  });
  await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
  return controller;
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
  testWidgets('starts at 100% (identity transform)', (tester) async {
    final controller = await _controllerWithResults(tester);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('+ increases zoom, − decreases it, Fit resets to 100%', (tester) async {
    final controller = await _controllerWithResults(tester);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('100%'), findsNothing);
    expect(find.text('125%'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('156%'), findsOneWidget); // 125% * 1.25, rounded

    await tester.tap(find.text('−'));
    await tester.pump();
    await tester.tap(find.text('−'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('100%'), findsNothing);

    await tester.tap(find.byIcon(Icons.crop_free));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('zoom does not exceed the 400% maximum', (tester) async {
    final controller = await _controllerWithResults(tester);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('+'));
      await tester.pump();
    }

    expect(find.text('400%'), findsOneWidget);
  });
}

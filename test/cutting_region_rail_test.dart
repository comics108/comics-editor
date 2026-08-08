// vdd-comics-editor-ai-uiux, Task 4.3: CuttingRegionRail's header summary, row rendering, and
// bulk "Accept all >N%" action.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/widgets/cutting_region_rail.dart';

Uint8List _samplePng() => Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 20)));

/// Polls with real delays -- must run inside `tester.runAsync` (a real Future.delayed inside the
/// fake-async test zone never fires; see balloon_editor_card_test.dart's documented history of
/// this exact hang).
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 60; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  await tester.pump();
}

DetectedRegion _region(String kind, double confidence) => DetectedRegion(
      kind: kind,
      confidence: confidence,
      bbox: const Rect.fromLTWH(0, 0, 20, 20),
      cropPng: _samplePng(),
    );

Future<EditorController> _controllerWithRegions(WidgetTester tester) async {
  final controller = EditorController();
  await tester.runAsync(() async {
    final opened = await controller.openPath('test/fixtures/sample.comics');
    if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
  });
  controller.cuttingClient = StubCuttingClient(
    stepDelay: Duration.zero,
    regions: [
      _region('background', 0.96),
      _region('character', 0.92),
      _region('balloon', 0.99),
      _region('art', 0.64),
    ],
  );
  await tester.runAsync(() async {
    controller.triggerCutting(_samplePng(), 0);
  });
  await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
  return controller;
}

/// Mirrors the real app's single root `AnimatedBuilder(animation: controller, ...)`
/// (`editor_screen.dart`) -- `CuttingRegionRail` itself doesn't self-subscribe to the
/// controller, consistent with every other panel in this app.
Widget _host(EditorController controller, {int? selected}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 600,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) =>
              CuttingRegionRail(controller: controller, selectedIndex: selected, onSelect: (_) {}),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty state before any regions exist', (tester) async {
    final controller = EditorController()..newDoc(DocType.comics);
    await tester.pumpWidget(_host(controller));
    expect(find.text('No regions yet'), findsOneWidget);
    expect(find.textContaining('Run Cut / Segment'), findsOneWidget);
  });

  testWidgets('header summary counts all 4 regions as pending', (tester) async {
    final controller = await _controllerWithRegions(tester);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('4 regions · 4 pending · 0 accepted · 0 rejected'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
  });

  testWidgets('accept-all-above-threshold button accepts only regions above 90%', (tester) async {
    final controller = await _controllerWithRegions(tester);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('Accept all >90% · 3 regions'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.textContaining('Accept all >90%'));
      await tester.pump();
    });
    // The tap's onPressed kicks off 3 sequential real tile-writes (acceptRegion) as a detached
    // Future -- tester.tap() doesn't await it, so wait for it to actually finish rather than
    // asserting immediately after a single pump.
    await _pumpUntil(
        tester,
        () => controller.cuttingSession!.regions
            .where((r) => r.status == RegionStatus.accepted)
            .length == 3);

    final regions = controller.cuttingSession!.regions;
    expect(regions[0].status, RegionStatus.accepted); // 96%
    expect(regions[1].status, RegionStatus.accepted); // 92%
    expect(regions[2].status, RegionStatus.accepted); // 99%
    expect(regions[3].status, RegionStatus.pending); // 64%, below threshold
  });

  testWidgets('tapping a row calls onSelect with its index', (tester) async {
    final controller = await _controllerWithRegions(tester);
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 600,
          child: CuttingRegionRail(
            controller: controller,
            selectedIndex: null,
            onSelect: (i) => selected = i,
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('#2'));
    expect(selected, 1);
  });

  testWidgets('rejected rows are dimmed and struck through', (tester) async {
    final controller = await _controllerWithRegions(tester);
    controller.rejectRegion(3);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final text = tester.widget<Text>(find.text('#4'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });
}

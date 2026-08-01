// vdd-comics-editor-ai-uiux, Task 4.2: CuttingReviewCard's kind-conditional actions and
// accept/reject/reclassify wiring, against a StubCuttingClient-populated session.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/widgets/cutting_review_card.dart';

Uint8List _samplePng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)));

/// A generous viewport so the whole card fits without needing to scroll to reach Accept/Reject/
/// the kind dropdown -- avoids `ensureVisible`/off-screen-tap fragility entirely, matching
/// balloon_editor_card_test.dart's own convention.
Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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

/// Opens the real sample.comics fixture (not `newDoc()`) -- Accept needs a real `tempFolder` to
/// tile-write into (`EditorController.acceptRegion` no-ops silently without one), matching every
/// other test file's convention for exercising real accept/save behavior.
Future<EditorController> _controllerWithSession(
  WidgetTester tester, {
  required String kind,
  RegionStatus status = RegionStatus.pending,
}) async {
  final controller = EditorController();
  await tester.runAsync(() async {
    final opened = await controller.openPath('test/fixtures/sample.comics');
    if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
  });
  controller.cuttingClient = StubCuttingClient(
    stepDelay: Duration.zero,
    regions: [
      DetectedRegion(
        kind: kind,
        confidence: 0.9,
        bbox: const Rect.fromLTWH(0, 0, 40, 30),
        cropPng: _samplePng(),
      ),
    ],
  );
  await tester.runAsync(() async {
    controller.triggerCutting(_samplePng(), 0);
  });
  await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
  controller.cuttingSession!.regions[0].status = status;
  return controller;
}

/// The real app rebuilds everything via one root `AnimatedBuilder(animation: controller, ...)`
/// (see `editor_screen.dart`'s `EditorScreen.build`) -- individual widgets don't self-subscribe
/// to `EditorController`. Mirroring that here (rather than tapping and hoping a bare `pump()`
/// happens to rebuild something) is what makes post-mutation UI assertions meaningful.
Widget _host(EditorController controller) {
  return MaterialApp(
    home: Scaffold(
      // CuttingReviewCard, like BalloonEditorCard, expects its host to provide scrolling --
      // it's not internally scrollable (matches the app's existing convention of the *panel*,
      // not the card, owning scroll behavior).
      body: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CuttingReviewCard(controller: controller, regionIndex: 0),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pending character region shows kind chip, confidence, and Insert-into-library '
      'disabled until accepted', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _controllerWithSession(tester, kind: 'character');
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('Region #1'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    // "Insert into library" is shown but disabled pre-accept, per Specifications.
    final insertButton = tester.widget<OutlinedButton>(
        find.ancestor(of: find.text('Insert into library'), matching: find.byType(OutlinedButton)));
    expect(insertButton.onPressed, isNull);
  });

  testWidgets('balloon region never shows Insert into library, shows Open in Lettering once accepted',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = await _controllerWithSession(tester, kind: 'balloon');
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(find.text('Insert into library'), findsNothing);
    expect(find.text('Open in Lettering'), findsNothing); // not accepted yet

    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => CuttingReviewCard(
              controller: controller,
              regionIndex: 0,
              onOpenInLettering: () => opened = true,
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.text('Accept'));
      await tester.pump();
    });
    await _pumpUntil(
        tester, () => controller.cuttingSession!.regions[0].status == RegionStatus.accepted);

    expect(find.text('Open in Lettering'), findsOneWidget);
    await tester.tap(find.text('Open in Lettering'));
    expect(opened, isTrue);
  });

  testWidgets('tapping Accept calls acceptRegion and updates the action row', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _controllerWithSession(tester, kind: 'art');
    await tester.pumpWidget(_host(controller));
    await tester.runAsync(() async {
      await tester.tap(find.text('Accept'));
      await tester.pump();
    });
    await _pumpUntil(
        tester, () => controller.cuttingSession!.regions[0].status == RegionStatus.accepted);

    expect(controller.cuttingSession!.regions[0].status, RegionStatus.accepted);
    expect(find.text('Accepted — now a layer'), findsOneWidget);
  });

  testWidgets('tapping Reject then Undo returns the region to pending', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _controllerWithSession(tester, kind: 'art');
    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Reject'));
    await tester.pump();

    expect(controller.cuttingSession!.regions[0].status, RegionStatus.rejected);
    expect(find.text('Rejected'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(controller.cuttingSession!.regions[0].status, RegionStatus.pending);
  });

  testWidgets('changing the kind dropdown calls reclassifyRegion', (tester) async {
    await _setLargeViewport(tester);
    final controller = await _controllerWithSession(tester, kind: 'art');
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Character').last);
    await tester.pumpAndSettle();

    expect(controller.cuttingSession!.regions[0].region.kind, 'character');
  });
}

// vdd-comics-editor-ai-uiux, Tasks 4.1 + 4.4: CuttingCanvas's trigger/running/failure/results
// states, walked against 02-visual.md, using StubCuttingClient to force each outcome. Opens the
// real sample.comics fixture (matching balloon_editor_card_test.dart's convention) so there's a
// genuine tiled layer to use as a Cutting source.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/widgets/cutting_canvas.dart';

/// Polls with real delays -- must run inside `tester.runAsync` (a real Future.delayed inside the
/// fake-async test zone never fires; see balloon_editor_card_test.dart's documented history of
/// this exact hang).
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 60; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

Future<EditorController> _openSample(WidgetTester tester) async {
  final controller = EditorController();
  await tester.runAsync(() async {
    final opened = await controller.openPath('test/fixtures/sample.comics');
    if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
  });
  return controller;
}

/// Mirrors the real app's single root `AnimatedBuilder(animation: controller, ...)`
/// (`editor_screen.dart`) -- `CuttingCanvas` itself doesn't self-subscribe to the controller.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('trigger screen prompts to select a layer when none is selected', (tester) async {
    final controller = await _openSample(tester);
    controller.selKind = SelKind.none;
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('Select a layer'), findsOneWidget);
  });

  testWidgets('trigger screen shows the selected layer name and a Cut / Segment button',
      (tester) async {
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.textContaining('Source:'), findsOneWidget);
    expect(find.text('Cut / Segment'), findsOneWidget);
  });

  testWidgets('tapping Cut / Segment starts a session and shows the running state, '
      'then the results canvas with region overlays', (tester) async {
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    controller.cuttingClient = StubCuttingClient(stepDelay: const Duration(milliseconds: 30));

    await tester.pumpWidget(_host(controller));
    await tester.runAsync(() async {
      await tester.tap(find.text('Cut / Segment'));
      await tester.pump();
    });
    await tester.pump();

    await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(controller.cuttingSession, isNotNull);
    expect(controller.cuttingSession!.regions, hasLength(4));
    // Region overlay markers ("#1".."#4") should be present on the results canvas.
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
  });

  testWidgets('failure state shows the mapped message and a Retry button when retryable',
      (tester) async {
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    controller.cuttingClient = StubCuttingClient(
      stepDelay: Duration.zero,
      outcome: StubCuttingOutcome.processError,
    );

    await tester.runAsync(() async {
      controller.triggerCutting(_bytesFor(controller), 0);
    });
    await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('Cutting failed.'), findsOneWidget);
    expect(find.textContaining('failed unexpectedly'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('non-retryable failure (e.g. missing checkpoint) shows no Retry button',
      (tester) async {
    final controller = await _openSample(tester);
    controller.selectLayer(0);
    controller.cuttingClient = StubCuttingClient(
      stepDelay: Duration.zero,
      outcome: StubCuttingOutcome.modelCheckpointNotFound,
    );

    await tester.runAsync(() async {
      controller.triggerCutting(_bytesFor(controller), 0);
    });
    await _pumpUntil(tester, () => controller.cuttingSession?.completed == true);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('Cutting failed.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });
}

/// A stand-in for the real stitched source bytes -- the failure-path tests don't care what the
/// bytes actually are, only that a session gets created; avoids duplicating the trigger screen's
/// own stitching logic in every test.
Uint8List _bytesFor(EditorController controller) => Uint8List(16);

// vdd-comics-editor-ai-uiux, follow-up: EditorController.refreshCuttingStaleness /
// dismissCuttingStale -- the "source image changed after regions were generated" edge case from
// Requirements, using the real sample.comics fixture so the source layer has real, replaceable
// tiled artwork (a fresh newDoc() layer has none, per Finding 3.2's own precedent).
import 'dart:typed_data';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/ui/controller.dart';

Uint8List _samplePng([int width = 40, int height = 30]) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 60; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
}

Future<EditorController> _openWithCompletedSession(WidgetTester tester) async {
  final controller = EditorController();
  await tester.runAsync(() async {
    final opened = await controller.openPath('test/fixtures/sample.comics');
    if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
  });
  controller.cuttingClient = StubCuttingClient(
    stepDelay: Duration.zero,
    regions: [
      DetectedRegion(
        kind: 'character',
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
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('freshly-triggered session is not stale', (tester) async {
    final controller = await _openWithCompletedSession(tester);
    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isFalse);
  });

  testWidgets(
      'replacing the source layer\'s artwork (different dimensions) marks the session stale',
      (tester) async {
    final controller = await _openWithCompletedSession(tester);
    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isFalse);

    controller.selectLayer(0);
    await tester.runAsync(() async {
      // Deliberately different dimensions from whatever the fixture's own artwork is, so the
      // fingerprint mismatch is unambiguous regardless of the fixture's real starting size.
      await controller.setImageFile('en', _samplePng(999, 777));
    });

    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isTrue);
  });

  testWidgets('dismissCuttingStale clears the flag without re-running', (tester) async {
    final controller = await _openWithCompletedSession(tester);
    controller.selectLayer(0);
    await tester.runAsync(() async {
      await controller.setImageFile('en', _samplePng(999, 777));
    });
    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isTrue);

    final sessionBefore = controller.cuttingSession;
    controller.dismissCuttingStale();
    expect(controller.cuttingSession!.stale, isFalse);
    expect(controller.cuttingSession, same(sessionBefore)); // same session, not re-run
  });

  testWidgets('deleting the source layer marks the session stale', (tester) async {
    final controller = await _openWithCompletedSession(tester);
    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isFalse);

    controller.selectLayer(0);
    controller.deleteSelected();

    controller.refreshCuttingStaleness();
    expect(controller.cuttingSession!.stale, isTrue);
  });

  testWidgets('refreshCuttingStaleness is a no-op with no session or no open document', (tester) async {
    final controller = EditorController();
    controller.refreshCuttingStaleness(); // no doc open at all -- must not throw
    expect(controller.cuttingSession, isNull);
  });

  testWidgets('dismissCuttingStale is a no-op when nothing is stale', (tester) async {
    final controller = await _openWithCompletedSession(tester);
    controller.dismissCuttingStale(); // never went stale -- must not throw or misbehave
    expect(controller.cuttingSession!.stale, isFalse);
  });
}

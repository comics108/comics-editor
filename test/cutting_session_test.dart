// vdd-comics-editor-ai-uiux, Tasks 3.1-3.4: EditorController's Cutting-mode state and mutations
// -- triggerCutting/cancelCutting (session lifecycle against StubCuttingClient),
// reject/reclassify/adjustRegionBbox (CuttingSession-only, no filesystem writes),
// acceptRegion (the real region-to-layer plumbing, verified through a real save/reopen round
// trip), and insertIntoLibrary (plain filesystem append, kind-gated).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';

Uint8List _samplePng([int width = 40, int height = 50]) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(10, 20, 30, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _waitUntil(bool Function() condition, {int maxTries = 100}) async {
  for (var i = 0; i < maxTries; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('condition not met within timeout');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('triggerCutting / cancelCutting', () {
    test('success path populates CuttingSession with all canned regions as pending', () async {
      final controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero);

      controller.triggerCutting(_samplePng(), 0);
      expect(controller.cuttingSession, isNotNull);
      expect(controller.cuttingSession!.isRunning, isTrue);

      await _waitUntil(() => controller.cuttingSession?.completed == true);

      final session = controller.cuttingSession!;
      expect(session.hasFailed, isFalse);
      expect(session.regions, hasLength(4));
      expect(session.regions.every((r) => r.status == RegionStatus.pending), isTrue);
    });

    test('failure path sets failureReason/failureRetryable, no regions', () async {
      final controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient = StubCuttingClient(
        stepDelay: Duration.zero,
        outcome: StubCuttingOutcome.modelCheckpointNotFound,
      );

      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);

      final session = controller.cuttingSession!;
      expect(session.hasFailed, isTrue);
      expect(session.failureReason, 'model_checkpoint_not_found');
      expect(session.failureRetryable, isFalse);
      expect(session.regions, isEmpty);
    });

    test('a zero-region Success is treated as completed, not still running', () async {
      final controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient =
          StubCuttingClient(stepDelay: Duration.zero, regions: const []);

      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);

      expect(controller.cuttingSession!.isRunning, isFalse);
      expect(controller.cuttingSession!.regions, isEmpty);
    });

    test('cancelCutting clears the session back to null', () async {
      final controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient = StubCuttingClient(stepDelay: const Duration(milliseconds: 50));

      controller.triggerCutting(_samplePng(), 0);
      expect(controller.cuttingSession, isNotNull);
      controller.cancelCutting();
      expect(controller.cuttingSession, isNull);

      // Give the (cancelled) stub stream a chance to fire late events -- must not resurrect a
      // cleared session (the `identical(cuttingSession, session)` guard in triggerCutting).
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.cuttingSession, isNull);
    });

    test('triggering a new session while one is in flight replaces it cleanly', () async {
      final controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient = StubCuttingClient(stepDelay: const Duration(milliseconds: 30));

      controller.triggerCutting(_samplePng(), 0);
      final firstSession = controller.cuttingSession;
      controller.triggerCutting(_samplePng(), 0);
      expect(controller.cuttingSession, isNot(same(firstSession)));

      await _waitUntil(() => controller.cuttingSession?.completed == true);
      expect(controller.cuttingSession!.regions, hasLength(4));
    });
  });

  group('reclassifyRegion / adjustRegionBbox / reject / unreject', () {
    late EditorController controller;

    setUp(() async {
      controller = EditorController()..newDoc(DocType.comics);
      controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero);
      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);
    });

    test('reclassifyRegion changes kind only while pending', () {
      controller.reclassifyRegion(0, 'balloon');
      expect(controller.cuttingSession!.regions[0].region.kind, 'balloon');

      controller.rejectRegion(0);
      controller.reclassifyRegion(0, 'art'); // no-op: already rejected
      expect(controller.cuttingSession!.regions[0].region.kind, 'balloon');
    });

    test('adjustRegionBbox changes bbox only while pending', () {
      const newBbox = Rect.fromLTWH(1, 2, 3, 4);
      controller.adjustRegionBbox(1, newBbox);
      expect(controller.cuttingSession!.regions[1].region.bbox, newBbox);
    });

    test('rejectRegion marks rejected; unrejectRegion returns it to pending', () {
      controller.rejectRegion(2);
      expect(controller.cuttingSession!.regions[2].status, RegionStatus.rejected);
      controller.unrejectRegion(2);
      expect(controller.cuttingSession!.regions[2].status, RegionStatus.pending);
    });

    test('unrejectRegion is a no-op on a region that was never rejected', () {
      controller.unrejectRegion(3);
      expect(controller.cuttingSession!.regions[3].status, RegionStatus.pending);
    });
  });

  group('acceptRegion', () {
    test(
        'writes real tiles, creates a real Layer with correct kind and position, '
        'and the position survives a real save/reopen round trip', () async {
      final controller = EditorController();
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) {
        fail('failed to open sample.comics: ${controller.coreError}');
      }
      addTearDown(controller.dispose);

      final sourceLayer = controller.doc!.layers[0];
      final sourceTranslate = sourceLayer.translate;
      const bbox = Rect.fromLTWH(37, 58, 80, 64);
      final expectedPosition = sourceTranslate + bbox.topLeft;

      final region = DetectedRegion(
        kind: 'character',
        confidence: 0.9,
        bbox: bbox,
        cropPng: _samplePng(80, 64),
      );
      controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero, regions: [region]);
      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);

      final beforeCount = controller.doc!.layers.length;
      await controller.acceptRegion(0);

      expect(controller.doc!.layers.length, beforeCount + 1);
      expect(controller.cuttingSession!.regions[0].status, RegionStatus.accepted);
      final newLayer = controller.doc!.layers.last;
      expect(newLayer.kind, 'character');
      expect(newLayer.translate.dx, closeTo(expectedPosition.dx, 0.001));
      expect(newLayer.translate.dy, closeTo(expectedPosition.dy, 0.001));

      // Real round trip: save, reopen, confirm the TranslateAnim's x AND y (not just the
      // in-memory `translate` field) actually persisted -- the concrete risk flagged in
      // acceptRegion's own doc comment (EditorLayer only sets `.y` by default).
      final savedPath =
          '${Directory.systemTemp.createTempSync('cutting_accept_roundtrip').path}/out.comics';
      await controller.core.call('saveComics', {
        'path': savedPath,
        'comics': comicsToCore(controller.coreDoc!),
      });

      final reopenController = EditorController();
      addTearDown(reopenController.dispose);
      final reopened = await reopenController.openPath(savedPath);
      expect(reopened, isTrue);
      final reopenedLayer = reopenController.doc!.layers.last;
      expect(reopenedLayer.kind, 'character');
      expect(reopenedLayer.translate.dx, closeTo(expectedPosition.dx, 0.001));
      expect(reopenedLayer.translate.dy, closeTo(expectedPosition.dy, 0.001));
    });

    test('is a no-op for an already-accepted or already-rejected region', () async {
      final controller = EditorController();
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) fail('failed to open sample.comics: ${controller.coreError}');
      addTearDown(controller.dispose);

      final region = DetectedRegion(
        kind: 'art',
        confidence: 0.5,
        bbox: const Rect.fromLTWH(0, 0, 10, 10),
        cropPng: _samplePng(10, 10),
      );
      controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero, regions: [region]);
      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);

      controller.rejectRegion(0);
      final countBefore = controller.doc!.layers.length;
      await controller.acceptRegion(0); // no-op: already rejected
      expect(controller.doc!.layers.length, countBefore);
    });
  });

  group('insertIntoLibrary', () {
    late Directory tempLibrary;
    late EditorController controller;

    setUp(() async {
      tempLibrary = Directory.systemTemp.createTempSync('cutting_library_test');
      controller = EditorController()..newDoc(DocType.comics);
      controller.resolveLibraryDir = () => tempLibrary.path;
    });

    tearDown(() {
      if (tempLibrary.existsSync()) tempLibrary.deleteSync(recursive: true);
    });

    Future<void> triggerWithKind(String kind) async {
      final region = DetectedRegion(
        kind: kind,
        confidence: 0.8,
        bbox: const Rect.fromLTWH(0, 0, 20, 20),
        cropPng: _samplePng(20, 20),
      );
      controller.cuttingClient = StubCuttingClient(stepDelay: Duration.zero, regions: [region]);
      controller.triggerCutting(_samplePng(), 0);
      await _waitUntil(() => controller.cuttingSession?.completed == true);
    }

    test('character region writes into <library>/characters/<name>/', () async {
      await triggerWithKind('character');
      final ok = await controller.insertIntoLibrary(0, 'amba');
      expect(ok, isTrue);
      final files = Directory('${tempLibrary.path}/characters/amba').listSync();
      expect(files, hasLength(1));
    });

    test('background region writes into <library>/environments/<name>/', () async {
      await triggerWithKind('background');
      final ok = await controller.insertIntoLibrary(0, 'palace-hall');
      expect(ok, isTrue);
      expect(Directory('${tempLibrary.path}/environments/palace-hall').listSync(), hasLength(1));
    });

    test('blank name defaults to "unclustered"', () async {
      await triggerWithKind('character');
      await controller.insertIntoLibrary(0, '   ');
      expect(Directory('${tempLibrary.path}/characters/unclustered').listSync(), hasLength(1));
    });

    test('appends to an existing name without disturbing prior files', () async {
      await triggerWithKind('character');
      await controller.insertIntoLibrary(0, 'amba');
      await triggerWithKind('character');
      await controller.insertIntoLibrary(0, 'amba');
      expect(Directory('${tempLibrary.path}/characters/amba').listSync(), hasLength(2));
    });

    test('balloon/art kinds are a no-op (no library bucket for them)', () async {
      await triggerWithKind('balloon');
      final ok = await controller.insertIntoLibrary(0, 'x');
      expect(ok, isFalse);
      expect(Directory('${tempLibrary.path}/characters').existsSync(), isFalse);
      expect(Directory('${tempLibrary.path}/environments').existsSync(), isFalse);
    });

    test('returns false when the library dir cannot be resolved', () async {
      controller.resolveLibraryDir = () => null;
      await triggerWithKind('character');
      final ok = await controller.insertIntoLibrary(0, 'x');
      expect(ok, isFalse);
    });
  });
}

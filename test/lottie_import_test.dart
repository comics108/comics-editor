// tdd-dot-lottie-import-export, Plan Task 3.1-3.3: ExportImportMode
// detection + ImportPreview.build, both modes. Real-fixture cases skip
// (not fail) when samples/dataset/ aren't present in this checkout.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/lottie_mapping.dart';
import 'package:comics_editor/src/ui/lottie/lottie_import.dart';

void main() {
  final repoRoot = Directory(Directory.current.path).parent.parent;
  final samplesDir = Directory('${repoRoot.path}/samples');
  final ashesFile = File(
    '${samplesDir.path}/sample_playback_viewport.lottie_unzip/ASHES_content/ASHES.json',
  );
  final ashesAvailable = ashesFile.existsSync();

  LottieDocument loadAshes() =>
      parseLottieJson(jsonDecode(ashesFile.readAsStringSync()) as Map<String, dynamic>);

  group('detectMode', () {
    test('the real ASHES.json (720x1600, real root sweeps) detects as playbackViewport', () {
      expect(detectMode(loadAshes()), ExportImportMode.playbackViewport);
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('a tall, canvas-shaped composition with no sweep detects as fullCanvas', () {
      final doc = LottieDocument(
        width: 1080,
        height: 41500, // matches sample_v2012.comics_unzip's real ~38:1 shape
        frameRate: 60,
        inPoint: 0,
        outPoint: 1000,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'bg',
            transform: LottieTransform(
              position: LottieProperty.static(const [540, 1000, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: const [],
      );
      expect(detectMode(doc), ExportImportMode.fullCanvas);
    });

    test('a viewport-shaped composition with no sweep still detects as fullCanvas '
        '(shape alone is not enough)', () {
      final doc = LottieDocument(
        width: 720,
        height: 1600,
        frameRate: 60,
        inPoint: 0,
        outPoint: 1000,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'static image',
            transform: LottieTransform(
              position: LottieProperty.static(const [360, 800, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: const [],
      );
      expect(detectMode(doc), ExportImportMode.fullCanvas);
    });
  });

  group('ImportPreview.build -- Full Canvas mode', () {
    test('A1: all-clean file produces zero flagged layers', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'a', refId: 'image_0', transform: _staticTransform()),
          LottieLayer(type: LottieLayer.typeImage, name: 'b', refId: 'image_1', transform: _staticTransform()),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 10, height: 10, imagePath: 'data:image/png;base64,x'),
          LottieAsset(id: 'image_1', width: 10, height: 10, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      expect(preview.cleanCount, 2);
      expect(preview.flaggedCount, 0);
    });

    test('A2: a mix of image and shape layers flags only the shape layer', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'image', refId: 'image_0', transform: _staticTransform()),
          LottieLayer(type: LottieLayer.typeShape, name: 'shape', transform: _staticTransform()),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 10, height: 10, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      expect(preview.cleanCount, 1);
      expect(preview.flaggedCount, 1);
      final flagged = preview.layers.firstWhere((l) => l.status == LayerPreviewStatus.flagged);
      expect(flagged.reason, contains('shape layer'));
    });

    test('A2 edge case: an entirely-unsupported file produces 0 clean / N flagged', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeShape, name: 'shape1', transform: _staticTransform()),
          LottieLayer(type: LottieLayer.typeText, name: 'text1', transform: _staticTransform()),
        ],
        assets: const [],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      expect(preview.cleanCount, 0);
      expect(preview.flaggedCount, 2);
    });

    test('A3: a precomp layer expands to its members, all sharing one groupId/groupName', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typePrecomp, name: 'Character_Ashes', refId: 'comp_0', transform: _staticTransform()),
        ],
        assets: [
          LottieAsset(id: 'comp_0', layers: [
            LottieLayer(type: LottieLayer.typeImage, name: '32_1', refId: 'image_0', transform: _staticTransform()),
            LottieLayer(type: LottieLayer.typeImage, name: '32_3', refId: 'image_1', transform: _staticTransform()),
            LottieLayer(type: LottieLayer.typeImage, name: '32_4_bg', refId: 'image_2', transform: _staticTransform()),
          ]),
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
          LottieAsset(id: 'image_1', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
          LottieAsset(id: 'image_2', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      expect(preview.layers, hasLength(3)); // the precomp itself doesn't get its own row
      expect(preview.layers.every((l) => l.groupId == 'comp_0'), isTrue);
      expect(preview.layers.every((l) => l.groupName == 'Character_Ashes'), isTrue);
      expect(preview.cleanCount, 3);
    });

    test('parent index resolves to resolvedParent within the same composition', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'head', refId: 'image_0', transform: _staticTransform()),
          LottieLayer(type: LottieLayer.typeImage, name: 'arms', refId: 'image_1', parent: 0, transform: _staticTransform()),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
          LottieAsset(id: 'image_1', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final head = preview.layers.firstWhere((l) => l.sourceLayer.name == 'head');
      final arms = preview.layers.firstWhere((l) => l.sourceLayer.name == 'arms');
      expect(arms.resolvedParent, same(head));
    });

    test('F2: an image layer whose asset is missing is flagged missingAsset, others still clean', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'ok', refId: 'image_0', transform: _staticTransform()),
          LottieLayer(type: LottieLayer.typeImage, name: 'broken', refId: 'image_missing', transform: _staticTransform()),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final broken = preview.layers.firstWhere((l) => l.sourceLayer.name == 'broken');
      final ok = preview.layers.firstWhere((l) => l.sourceLayer.name == 'ok');
      expect(broken.status, LayerPreviewStatus.missingAsset);
      expect(ok.status, LayerPreviewStatus.clean);
    });
  });

  group('ImportPreview.build -- Playback Viewport mode (real ASHES.json)', () {
    test('G4/G5: detects 2 real scenes, all member layers scroll-basis-eligible (clean)', () {
      final doc = loadAshes();
      final preview = ImportPreview.build(doc, ExportImportMode.playbackViewport);

      final sceneIndices = preview.layers.map((l) => l.sceneIndex).whereType<int>().toSet();
      expect(sceneIndices, {0, 1}); // 2 real scenes: "All Objects1"/"All Objects2"
      expect(preview.cleanCount, greaterThan(50)); // real content has 61+40 member layers
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('G4/G6: scrollSpeed auto-derives to ~2.4916-2.5001 px/frame (real computed range)', () {
      final doc = loadAshes();
      final preview = ImportPreview.build(doc, ExportImportMode.playbackViewport);
      expect(preview.scrollSpeed, isNotNull);
      expect(preview.scrollSpeed, closeTo(2.4958, 0.01)); // average of 2.4916/2.5001
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('a fullCanvas-shaped document has no derivable scroll speed (null)', () {
      final doc = LottieDocument(
        width: 1080, height: 41500, frameRate: 60, inPoint: 0, outPoint: 1000,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'bg', transform: _staticTransform()),
        ],
        assets: const [],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.playbackViewport);
      expect(preview.scrollSpeed, isNull);
      expect(preview.flaggedCount, 1); // the one root layer, not a recognized scene
    });
  });
}

LottieTransform _staticTransform() => LottieTransform(
      position: LottieProperty.static(const [0, 0, 0]),
      rotation: LottieProperty.static(const [0]),
      scale: LottieProperty.static(const [100, 100, 100]),
      opacity: LottieProperty.static(const [100]),
    );

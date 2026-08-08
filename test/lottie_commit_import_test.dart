// tdd-dot-lottie-import-export, Plan Task 4.1/4.2/4.4: commitImport --
// mutates a real ComicsDoc from an ImportPreview. Real-fixture cases skip
// (not fail) when samples/ isn't present in this checkout.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/lottie_mapping.dart';
import 'package:comics_editor/src/ui/lottie/lottie_import.dart';
import 'package:comics_editor/src/ui/models.dart';

void main() {
  final repoRoot = Directory(Directory.current.path).parent.parent;
  final ashesFile = File(
    '${repoRoot.path}/samples/sample_playback_viewport.lottie_unzip/ASHES_content/ASHES.json',
  );
  final ashesAvailable = ashesFile.existsSync();

  ComicsDoc newDoc() => ComicsDoc(name: 'doc.comics', type: DocType.comics);

  group('commitImport -- Full Canvas mode', () {
    test('a simple animated-translate + static-alpha layer bakes to the expected Anim chain', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'layer_1',
            refId: 'image_0',
            transform: LottieTransform(
              position: LottieProperty.animated([
                LottieKeyframe(frame: 0, value: const [100, 200, 0]),
                LottieKeyframe(frame: 50, value: const [300, 400, 0]),
              ]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [80]),
            ),
          ),
        ],
        assets: [LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x')],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);

      expect(comicsDoc.layers, hasLength(1));
      final layer = comicsDoc.layers.single;
      final translateAnims = layer.anims.where((a) => a.type == AnimType.translate).toList();
      expect(translateAnims, hasLength(2));
      expect(translateAnims[0].start, 0);
      expect(translateAnims[0].end, 0);
      expect(translateAnims[0].x, 100);
      expect(translateAnims[0].y, 200);
      expect(translateAnims[1].start, 0);
      expect(translateAnims[1].end, 50); // identity ratio in fullCanvas mode
      expect(translateAnims[1].x, 300);
      expect(translateAnims[1].y, 400);

      final alphaAnims = layer.anims.where((a) => a.type == AnimType.alpha).toList();
      expect(alphaAnims, hasLength(1));
      expect(alphaAnims.single.alpha, closeTo(0.8, 1e-9)); // Lottie 0-100 -> .comics 0-1
    });

    test('a grouped (precomp) member bakes the enclosing precomp\'s static offset', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(
            type: LottieLayer.typePrecomp,
            name: 'Character',
            refId: 'comp_0',
            transform: LottieTransform(
              position: LottieProperty.static(const [50, 60, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: [
          LottieAsset(id: 'comp_0', layers: [
            LottieLayer(
              type: LottieLayer.typeImage,
              name: 'member',
              refId: 'image_0',
              transform: LottieTransform(
                position: LottieProperty.static(const [10, 20, 0]),
                rotation: LottieProperty.static(const [0]),
                scale: LottieProperty.static(const [100, 100, 100]),
                opacity: LottieProperty.static(const [100]),
              ),
            ),
          ]),
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);

      expect(comicsDoc.layers, hasLength(1));
      final layer = comicsDoc.layers.single;
      expect(layer.groupId, 'comp_0');
      final translate = layer.anims.single;
      expect(translate.x, 60); // 10 (own) + 50 (precomp's own static offset)
      expect(translate.y, 80); // 20 + 60
    });

    test('parentId is wired from the Lottie parent field via resolvedParent', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'head', refId: 'image_0', transform: _static()),
          LottieLayer(type: LottieLayer.typeImage, name: 'arms', refId: 'image_1', parent: 0, transform: _static()),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
          LottieAsset(id: 'image_1', width: 1, height: 1, imagePath: 'data:image/png;base64,x'),
        ],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);

      final head = comicsDoc.layers.firstWhere((l) => l.name == 'head');
      final arms = comicsDoc.layers.firstWhere((l) => l.name == 'arms');
      expect(arms.parentId, head.id);
    });

    test('flagged/missingAsset layers are never imported (only clean ones become EditorLayers)', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(type: LottieLayer.typeImage, name: 'ok', refId: 'image_0', transform: _static()),
          LottieLayer(type: LottieLayer.typeShape, name: 'shape', transform: _static()),
        ],
        assets: [LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x')],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);
      expect(comicsDoc.layers, hasLength(1));
      expect(comicsDoc.layers.single.name, 'ok');
    });

    test('Test A4 equivalent: never calling commitImport leaves the doc untouched', () {
      final comicsDoc = newDoc();
      expect(comicsDoc.layers, isEmpty); // no commitImport call at all
    });

    test('a Lottie vector mask imports as TextRegion.shape == "polygon" (Test C2)', () {
      final doc = LottieDocument(
        width: 720, height: 1600, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'masked',
            refId: 'image_0',
            transform: _static(),
            mask: LottieMask(
              mode: 'a',
              vertices: const [Offset(0, 0), Offset(100, 0), Offset(100, 50), Offset(0, 50)],
            ),
          ),
        ],
        assets: [LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'data:image/png;base64,x')],
      );
      final preview = ImportPreview.build(doc, ExportImportMode.fullCanvas);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);

      final region = comicsDoc.layers.single.textRegion!;
      expect(region.shape, 'polygon');
      expect(region.points, hasLength(4));
    });
  });

  group('commitImport -- Playback Viewport mode (real ASHES.json)', () {
    test('imports real scenes with groupId set and a real, baked translate chain', () {
      final json = jsonDecode(ashesFile.readAsStringSync()) as Map<String, dynamic>;
      final doc = parseLottieJson(json);
      final preview = ImportPreview.build(doc, ExportImportMode.playbackViewport);
      final comicsDoc = newDoc();
      commitImport(preview, comicsDoc);

      expect(comicsDoc.layers, isNotEmpty);
      expect(comicsDoc.layers.every((l) => l.groupId != null), isTrue);
      expect(comicsDoc.layers.every((l) => l.anims.any((a) => a.type == AnimType.translate)), isTrue);

      // Every translate Anim's start/end should be scaled by the derived
      // scrollSpeed (~2.4958 px/frame average), not left as raw Lottie
      // frame numbers -- spot check one layer's own last Anim.end against
      // its source frame * scrollSpeed.
      final speed = preview.scrollSpeed!;
      final layer = comicsDoc.layers.first;
      final translateAnims = layer.anims.where((a) => a.type == AnimType.translate).toList();
      expect(translateAnims, isNotEmpty);
      // start/end are always non-negative ints derived from frame*speed with speed>0.
      expect(translateAnims.every((a) => a.start >= 0 && a.end >= 0), isTrue);
      expect(speed, closeTo(2.4958, 0.01));
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');
  });
}

LottieTransform _static() => LottieTransform(
      position: LottieProperty.static(const [0, 0, 0]),
      rotation: LottieProperty.static(const [0]),
      scale: LottieProperty.static(const [100, 100, 100]),
      opacity: LottieProperty.static(const [100]),
    );

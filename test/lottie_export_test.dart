// tdd-dot-lottie-import-export, Plan Task 5.1-5.4: buildLottieExport.
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/lottie_mapping.dart';
import 'package:comics_editor/src/ui/lottie/lottie_export.dart';
import 'package:comics_editor/src/ui/lottie/lottie_import.dart';
import 'package:comics_editor/src/ui/models.dart';

void main() {
  ComicsDoc newDoc({int width = 1080, int height = 20000}) =>
      ComicsDoc(name: 'doc.comics', type: DocType.comics, width: width, height: height);

  group('buildLottieExport -- Full Canvas mode', () {
    test('a simple 2-keyframe translate Anim chain exports to a matching Lottie position property', () {
      final doc = newDoc();
      final layer = EditorLayer('layer_1');
      layer.anims.clear();
      layer.anims.add(Anim(AnimType.translate, start: 0, end: 0)..x = 100..y = 200);
      layer.anims.add(Anim(AnimType.translate, start: 0, end: 50)..x = 300..y = 400);
      doc.layers.add(layer);

      final lottieDoc = buildLottieExport(doc, ExportImportMode.fullCanvas, easing: EasingChoice.easyEaseApproximation);

      expect(lottieDoc.width, 1080);
      expect(lottieDoc.height, 20000);
      expect(lottieDoc.layers, hasLength(1));
      final position = lottieDoc.layers.single.transform.position;
      expect(position.isAnimated, isTrue);
      expect(position.keyframes, hasLength(2));
      expect(position.keyframes!.first.frame, 0);
      expect(position.keyframes!.first.value, [100, 200, 0]);
      expect(position.keyframes!.last.frame, 50); // identity ratio, no scaling
      expect(position.keyframes!.last.value, [300, 400, 0]);
    });

    test('scale/alpha convert from .comics unit-fraction back to Lottie percentage (D1)', () {
      final doc = newDoc();
      final layer = EditorLayer('layer_1');
      layer.anims.clear();
      layer.anims.add(Anim(AnimType.translate)..y = 0);
      layer.anims.add(Anim(AnimType.scale, start: 0, end: 0)..scaleX = 0.5..scaleY = 0.5);
      layer.anims.add(Anim(AnimType.alpha, start: 0, end: 0)..alpha = 0.8);
      doc.layers.add(layer);

      final lottieDoc = buildLottieExport(doc, ExportImportMode.fullCanvas, easing: EasingChoice.easyEaseApproximation);
      final transform = lottieDoc.layers.single.transform;
      expect(transform.scale.staticValue, [50, 50, 100]);
      expect(transform.opacity.staticValue, [80]);
    });

    test('D2: layers sharing a groupId export as one precomp, not N independent roots', () {
      final doc = newDoc();
      final a = EditorLayer('a')..groupId = 'group-1';
      final b = EditorLayer('b')..groupId = 'group-1';
      doc.layers.addAll([a, b]);

      final lottieDoc = buildLottieExport(doc, ExportImportMode.fullCanvas, easing: EasingChoice.easyEaseApproximation);

      expect(lottieDoc.layers, hasLength(1)); // one precomp root, not 2
      expect(lottieDoc.layers.single.type, LottieLayer.typePrecomp);
      final precompAsset = lottieDoc.assets.firstWhere((asset) => asset.id == lottieDoc.layers.single.refId);
      expect(precompAsset.layers, hasLength(2));
    });

    test('D3: TextRegion.shape == "polygon" exports as a real Lottie vector mask', () {
      final doc = newDoc();
      final layer = EditorLayer('masked')
        ..textRegion = TextRegion(
          shape: 'polygon',
          points: const [Offset(0, 0), Offset(10, 0), Offset(10, 5), Offset(0, 5)],
        );
      doc.layers.add(layer);

      final lottieDoc = buildLottieExport(doc, ExportImportMode.fullCanvas, easing: EasingChoice.easyEaseApproximation);
      final mask = lottieDoc.layers.single.mask;
      expect(mask, isNotNull);
      expect(mask!.vertices, hasLength(4));
    });

    test('D3 edge case: TextRegion.shape == "mask" (raster) is skipped with no Lottie mask, not a crash', () {
      final doc = newDoc();
      final layer = EditorLayer('masked')..textRegion = TextRegion(shape: 'mask', maskFile: 'mask.png');
      doc.layers.add(layer);

      final lottieDoc = buildLottieExport(doc, ExportImportMode.fullCanvas, easing: EasingChoice.easyEaseApproximation);
      expect(lottieDoc.layers.single.mask, isNull); // disclosed limitation, not guessed
    });
  });

  group('buildLottieExport -- Playback Viewport mode', () {
    test('partitions layers into scenes, sweep spans each scene\'s own real scroll range', () {
      // DECIDED 2026-08-08, corrected via the real G6 round-trip test: a
      // scene's sweep range is derived from its members' own real
      // AnimType.translate start/end values (the frame values most
      // members agree on -- see `_scrollRangeOf`'s doc comment), **not**
      // an assumed uniform `sceneIndex * viewportHeight` band. Neither
      // layer here has a real (non-degenerate) translate anim, so each
      // singleton scene falls back to its own resting Y, padded by one
      // `preferredViewportHeight`.
      final doc = newDoc(width: 720, height: 3200)
        ..preferredViewportWidth = 720
        ..preferredViewportHeight = 1600;
      final sceneA = EditorLayer('in scene 0')..translate = const Offset(0, 500);
      sceneA.anims.clear();
      sceneA.anims.add(Anim(AnimType.translate)..y = 500);
      final sceneB = EditorLayer('in scene 1')..translate = const Offset(0, 2000);
      sceneB.anims.clear();
      sceneB.anims.add(Anim(AnimType.translate)..y = 2000);
      doc.layers.addAll([sceneA, sceneB]);

      final lottieDoc = buildLottieExport(
        doc,
        ExportImportMode.playbackViewport,
        scrollSpeed: 2.0,
        easing: EasingChoice.easyEaseApproximation,
      );

      expect(lottieDoc.width, 720);
      expect(lottieDoc.height, 1600);
      expect(lottieDoc.layers, hasLength(2)); // 2 scenes
      expect(lottieDoc.layers.every((l) => l.type == LottieLayer.typePrecomp), isTrue);

      final scene0 = lottieDoc.layers.firstWhere((l) => l.name == 'Scene 0');
      final sweep0 = scene0.transform.position;
      expect(sweep0.isAnimated, isTrue);
      // bandStartY=500 (sceneA's own resting Y), bandEndY=500+1600=2100,
      // scrollSpeed=2.0 -> inFrame=250, outFrame=1050
      expect(sweep0.keyframes!.first.frame, 250);
      expect(sweep0.keyframes!.first.value, [0, -500.0, 0]);
      expect(sweep0.keyframes!.last.frame, 1050);
      expect(sweep0.keyframes!.last.value, [0, -2100.0, 0]);

      final scene1 = lottieDoc.layers.firstWhere((l) => l.name == 'Scene 1');
      final sweep1 = scene1.transform.position;
      // bandStartY=2000, bandEndY=2000+1600=3600 -> inFrame=1000, outFrame=1800
      expect(sweep1.keyframes!.first.frame, 1000);
      expect(sweep1.keyframes!.last.frame, 1800);
    });

    test('export -> re-import round-trip recovers the same absolute position (no real pixel bytes needed for this check)', () {
      final doc = newDoc(width: 720, height: 3200)
        ..preferredViewportWidth = 720
        ..preferredViewportHeight = 1600;
      final layer = EditorLayer('character');
      layer.anims.clear();
      layer.anims.add(Anim(AnimType.translate)..y = 500);
      doc.layers.add(layer);

      const scrollSpeed = 2.0;
      final lottieDoc = buildLottieExport(
        doc,
        ExportImportMode.playbackViewport,
        scrollSpeed: scrollSpeed,
        easing: EasingChoice.easyEaseApproximation,
      );

      final preview = ImportPreview.build(lottieDoc, ExportImportMode.playbackViewport);
      preview.scrollSpeed = scrollSpeed; // same speed used for export, matching a real round-trip
      final reimported = ComicsDoc(name: 'doc.comics', type: DocType.comics);
      commitImport(preview, reimported);

      expect(reimported.layers, hasLength(1));
      final translate = reimported.layers.single.anims.firstWhere((a) => a.type == AnimType.translate);
      // original absolute Y was 500 -- member.localY (500, unchanged) + sweep
      // at the same scroll position should recover very close to 500 at
      // the scene's own start (scroll=bandStartY=0 -> sweep=0 -> total=500).
      expect(translate.y, closeTo(500, 1));
    });
  });
}

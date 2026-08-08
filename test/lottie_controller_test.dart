// tdd-dot-lottie-import-export, Plan Task 6.1-6.4: EditorController's
// .lottie import/export wiring -- pickLottieToImport/setLottieImportMode/
// setLottieScrollSpeed/setLottieEasingChoice/cancelLottieImport/
// commitLottieImport/exportLottieWithDialog. FilePicker itself isn't
// exercised here (it's a real platform plugin, not mockable from a plain
// `flutter test` run) -- these tests drive the same controller state
// `pickLottieToImport` would populate, directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/lottie_mapping.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/lottie/lottie_import.dart';
import 'package:comics_editor/src/ui/models.dart';

void main() {
  // Same real 1x1 PNG already used by test/process_cutting_client_test.dart.
  const onePxPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

  LottieDocument fullCanvasDocWithOneImage() => LottieDocument(
        width: 1080,
        height: 2000,
        frameRate: 60,
        inPoint: 0,
        outPoint: 100,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'imported_layer',
            refId: 'image_0',
            transform: LottieTransform(
              position: LottieProperty.static(const [540, 1000, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: [
          LottieAsset(
            id: 'image_0',
            width: 1,
            height: 1,
            imagePath: 'data:image/png;base64,$onePxPngBase64',
          ),
        ],
      );

  group('setLottieImportMode/setLottieScrollSpeed/setLottieEasingChoice', () {
    test('overriding the mode rebuilds the preview under the new mode', () {
      final c = EditorController();
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);
      expect(c.lottiePreview!.mode, ExportImportMode.fullCanvas);

      c.setLottieImportMode(ExportImportMode.playbackViewport);

      expect(c.lottiePreview!.mode, ExportImportMode.playbackViewport);
    });

    test('setting the same mode again is a no-op (does not rebuild)', () {
      final c = EditorController();
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);
      final before = c.lottiePreview;

      c.setLottieImportMode(ExportImportMode.fullCanvas);

      expect(c.lottiePreview, same(before));
    });

    test('setLottieScrollSpeed updates the current preview in place', () {
      final c = EditorController();
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.playbackViewport);

      c.setLottieScrollSpeed(3.5);

      expect(c.lottiePreview!.scrollSpeed, 3.5);
    });

    test('setLottieEasingChoice updates the current preview in place', () {
      final c = EditorController();
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);

      c.setLottieEasingChoice(EasingChoice.exactCubicFit);

      expect(c.lottiePreview!.easing, EasingChoice.exactCubicFit);
    });
  });

  group('cancelLottieImport (Test A4)', () {
    test('discards the preview without mutating the document', () {
      final c = EditorController();
      c.newDoc(DocType.comics);
      final layersBefore = c.doc!.layers.length;
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);

      c.cancelLottieImport();

      expect(c.lottiePreview, isNull);
      expect(c.doc!.layers.length, layersBefore);
    });
  });

  group('commitLottieImport (Plan Task 4.1/4.2 + 6.4)', () {
    test('without a tempFolder, adds real EditorLayers but keeps the placeholder image '
        '(disclosed scope boundary, matches commitImport\'s own documented fallback)', () async {
      final c = EditorController();
      c.newDoc(DocType.comics); // no coreDoc -> no tempFolder, same as every other tile-writing
      // feature in this app when there's no backing core session.
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);
      expect(c.coreDoc?.tempFolder, isNull);

      final ok = await c.commitLottieImport();

      expect(ok, isTrue);
      expect(c.doc!.layers, hasLength(1));
      expect(c.doc!.layers.single.name, 'imported_layer');
      // EditorLayer's own constructor placeholder (Images[0].file == name) --
      // never replaced, since there was no tempFolder to write real tiles into.
      expect(c.doc!.layers.single.images.first.file, 'imported_layer');
      expect(c.lottiePreview, isNull); // review dialog state cleared after commit
    });

    test('with a real tempFolder, writes real tiled pixel bytes and points the layer at them',
        () async {
      final c = EditorController();
      final opened = await c.openPath('test/fixtures/sample.comics');
      expect(opened, isTrue, reason: c.coreError);
      final tempFolder = c.coreDoc!.tempFolder;
      expect(tempFolder, isNotNull);

      final layersBefore = c.doc!.layers.length;
      c.lottiePreview = ImportPreview.build(fullCanvasDocWithOneImage(), ExportImportMode.fullCanvas);

      final ok = await c.commitLottieImport();

      expect(ok, isTrue);
      expect(c.doc!.layers, hasLength(layersBefore + 1));
      final imported = c.doc!.layers.last;
      final fileTemplate = imported.images.first.file;
      // Real tiles are never named after the raw layer name directly --
      // confirms this isn't still the constructor placeholder.
      expect(fileTemplate, isNot('imported_layer'));
      expect(fileTemplate, contains('{0}'));

      // Task 6.4's own bar: the actual tile file exists on disk with real,
      // non-empty pixel content -- not just a placeholder filename.
      final realFile = File(
        '$tempFolder/layers/${fileTemplate.replaceAll('{0}', '1000').replaceAll('{1}', '0').replaceAll('{2}', '0')}',
      );
      expect(realFile.existsSync(), isTrue);
      expect(realFile.lengthSync(), greaterThan(0));
    });

    test('a layer whose source asset is an external file reference (never seen in real content) '
        'is skipped for pixel-writing, keeping its placeholder -- a disclosed gap, not a crash',
        () async {
      final c = EditorController();
      final opened = await c.openPath('test/fixtures/sample.comics');
      expect(opened, isTrue, reason: c.coreError);

      final doc = LottieDocument(
        width: 1080, height: 2000, frameRate: 60, inPoint: 0, outPoint: 100,
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'external_ref_layer',
            refId: 'image_0',
            transform: LottieTransform(
              position: LottieProperty.static(const [0, 0, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 1, height: 1, imagePath: 'images/external.png'),
        ],
      );
      c.lottiePreview = ImportPreview.build(doc, ExportImportMode.fullCanvas);

      final ok = await c.commitLottieImport();

      expect(ok, isTrue);
      expect(c.doc!.layers.last.images.first.file, 'external_ref_layer');
    });
  });

  group('exportLottieWithDialog mode selection (Plan Task 6.1)', () {
    test('returns false with no open document', () async {
      final c = EditorController();
      final ok = await c.exportLottieWithDialog(ExportImportMode.fullCanvas);
      expect(ok, isFalse);
    });
  });

  group('Task 6.3 -- wrong-mode signal the review dialog banner reacts to', () {
    test('overriding away from the auto-detected mode is detectable via detectMode', () {
      final doc = fullCanvasDocWithOneImage(); // real shape: canvas-sized, no sweep
      final autoDetected = detectMode(doc);
      expect(autoDetected, ExportImportMode.fullCanvas);

      final c = EditorController();
      c.lottiePreview = ImportPreview.build(doc, autoDetected);
      expect(c.lottiePreview!.mode, detectMode(c.lottiePreview!.document));

      c.setLottieImportMode(ExportImportMode.playbackViewport);

      expect(c.lottiePreview!.mode, isNot(detectMode(c.lottiePreview!.document)));
    });
  });
}

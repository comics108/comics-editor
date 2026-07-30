// vdd-comics-editor-uiux-lettering, Task 2.3: EditorController.setImageFile/
// setImagePopup now write real bytes (tile-written via Task 2.2, slot
// resolved via the LanguageRegistry, Task 1.2) instead of a fake placeholder
// filename that was never actually written to disk. Verification per the
// plan: set an image for an existing-Cultures language and for a new
// registry language, saveComics, reopen, confirm both round-trip correctly
// with distinct, correct Images entries.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ui/controller.dart';

Uint8List _solidPng(int width, int height, int r, int g, int b) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setImageFile writes real tiles for an existing-Cultures language and '
      'a new registry language, both round-trip distinctly through save/reopen',
      () async {
    final controller = EditorController();
    // DartIoCore is always available (no external binary needed), so this
    // exercises a real core session end-to-end, same as the real app.
    final samplePath = 'test/fixtures/sample.comics';
    final opened = await controller.openPath(samplePath);
    expect(opened, isTrue);
    expect(controller.coreDoc?.tempFolder, isNotNull);

    controller.selectLayer(0);
    final layer = controller.selectedLayer!;
    final originalRuFile = layer.images[1].file; // untouched control slot

    await controller.setImageFile('en', _solidPng(600, 300, 200, 10, 10)); // existing slot (0)
    await controller.setImageFile('uk', _solidPng(300, 700, 10, 200, 10)); // new registry slot

    final registry = await controller.languageRegistry;
    final ukIndex = registry.indexFor('uk')!;
    expect(layer.images.length, ukIndex + 1);
    expect(layer.images[0].file, contains('_en_'));
    expect(layer.images[ukIndex].file, contains('_uk_'));
    expect(layer.images[1].file, originalRuFile); // ru untouched

    final savedPath =
        '${Directory.systemTemp.createTempSync('ctrl_imgbytes').path}/roundtrip.comics';
    final saved = await controller.saveToPath(savedPath);
    expect(saved, isTrue);

    final reopened = EditorController();
    expect(await reopened.openPath(savedPath), isTrue);
    final reopenedLayer = reopened.doc!.layers[0];

    expect(reopenedLayer.images[0].file, layer.images[0].file);
    expect(reopenedLayer.images[ukIndex].file, layer.images[ukIndex].file);
    // Distinct filenames -- the two writes didn't collide into one slot.
    expect(reopenedLayer.images[0].file, isNot(reopenedLayer.images[ukIndex].file));

    // Pixel content itself round-tripped correctly and distinctly (not just
    // the filename): decode the reopened en tile and confirm it's the red
    // pixel we wrote, not the uk layer's green.
    final tempFolder = reopened.coreDoc!.tempFolder!;
    final enTileFile =
        File('$tempFolder/layers/${reopenedLayer.images[0].file.replaceAll("{0}_{1}_{2}", "1000_0_0")}');
    expect(enTileFile.existsSync(), isTrue);
    final enTile = img.decodeImage(enTileFile.readAsBytesSync())!;
    final enPixel = enTile.getPixel(0, 0);
    expect(enPixel.r, 200);
    expect(enPixel.g, 10);
    expect(enPixel.b, 10);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('setImagePopup writes a single un-tiled file, distinct from setImageFile',
      () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.selectLayer(0);
    final layer = controller.selectedLayer!;

    await controller.setImagePopup('en', _solidPng(64, 64, 5, 5, 5));

    expect(layer.images[0].popup, isNotEmpty);
    expect(layer.images[0].popup.contains('{0}'), isFalse); // not a tile template

    final tempFolder = controller.coreDoc!.tempFolder!;
    final popupFile = File('$tempFolder/layers/${layer.images[0].popup}');
    expect(popupFile.existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('setImageFile/setImagePopup are a no-op with no selected layer', () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.addSound(); // selects a sound, so selectedLayer becomes null
    expect(controller.selectedLayer, isNull);
    // Should not throw despite no selection.
    await controller.setImageFile('en', _solidPng(10, 10, 1, 2, 3));
    await controller.setImagePopup('en', _solidPng(10, 10, 1, 2, 3));
  });
}

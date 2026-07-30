// vdd-comics-editor-uiux-lettering, Task 2.2: Dart tile writer, matching the
// editor's on-disk 512px tiling convention (FileManager.cs/ImageMagick.cs),
// already reimplemented once in apps/comics-ai-baloons/scripts/tiling.py.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:comics_editor/src/io/tile_writer.dart';

Uint8List _syntheticPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sanitizeStem', () {
    test('strips a tile template and extension off EditorLayer.name '
        '(the bug this exists to prevent: layer.name defaults to the first '
        "image's raw templated file value)", () {
      expect(sanitizeStem('0001_zastavka_2_{0}_{1}_{2}.png'), '0001_zastavka_2');
    });

    test('strips a plain extension when there is no template', () {
      expect(sanitizeStem('picked_En.png'), 'picked_En');
    });

    test('passes through an already-clean name unchanged', () {
      expect(sanitizeStem('layer3'), 'layer3');
    });

    test('falls back to "layer" for an empty/degenerate name', () {
      expect(sanitizeStem(''), 'layer');
      expect(sanitizeStem('{0}_{1}_{2}.png'), 'layer');
    });
  });

  test(
      'tile count/filenames/edge-clip match comics-ai-baloons\' own known-good '
      'layout (648x152 -> 2 cols x 1 row, edge tile 136px wide)', () async {
    final layersDir = Directory.systemTemp.createTempSync('tilewriter_grid').path;
    final tiled = await writeTiles(
      bytes: _syntheticPng(648, 152),
      layersDir: layersDir,
      name: 'b1_eng',
    );

    expect(tiled.width, 648);
    expect(tiled.height, 152);
    expect(tiled.fileTemplate, 'b1_eng_{0}_{1}_{2}.png');

    final files = Directory(layersDir).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, {'b1_eng_1000_0_0.png', 'b1_eng_1000_1_0.png'});

    final edgeTile = img.decodeImage(File('$layersDir/b1_eng_1000_1_0.png').readAsBytesSync())!;
    expect(edgeTile.width, 648 - 512);
    expect(edgeTile.height, 152);
    final fullTile = img.decodeImage(File('$layersDir/b1_eng_1000_0_0.png').readAsBytesSync())!;
    expect(fullTile.width, 512);
    expect(fullTile.height, 152);
  });

  test('exact multiple of 512 produces no trailing empty tile row/col', () async {
    final layersDir = Directory.systemTemp.createTempSync('tilewriter_exact').path;
    final tiled = await writeTiles(
      bytes: _syntheticPng(1024, 512),
      layersDir: layersDir,
      name: 'exact',
    );
    expect(tiled.width, 1024);
    expect(tiled.height, 512);
    final files = Directory(layersDir).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, {'exact_1000_0_0.png', 'exact_1000_1_0.png'});
  });

  test('deleteTiles removes only tiles matching the given template', () async {
    final layersDir = Directory.systemTemp.createTempSync('tilewriter_delete').path;
    await writeTiles(bytes: _syntheticPng(600, 300), layersDir: layersDir, name: 'old');
    await writeTiles(bytes: _syntheticPng(600, 300), layersDir: layersDir, name: 'old2');
    final beforeOld = Directory(layersDir)
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('old_'))
        .length;
    expect(beforeOld, greaterThan(0));

    await deleteTiles(layersDir, 'old_{0}_{1}_{2}.png');

    final remaining = Directory(layersDir).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(remaining.where((n) => n.startsWith('old_')), isEmpty);
    // old2's tiles (different name, same prefix family) must survive.
    expect(remaining.where((n) => n.startsWith('old2_')), isNotEmpty);
  });

  test('deleteTiles is a no-op for a non-tile template or missing directory', () async {
    await deleteTiles('/nonexistent/dir', 'x_{0}_{1}_{2}.png');
    final layersDir = Directory.systemTemp.createTempSync('tilewriter_noop').path;
    await writeTiles(bytes: _syntheticPng(100, 100), layersDir: layersDir, name: 'kept');
    await deleteTiles(layersDir, 'kept.png'); // no {0} placeholder -> not a tile template
    expect(Directory(layersDir).listSync(), isNotEmpty);
  });

  group('stitchImage', () {
    test('reconstructs the original image pixel-for-pixel from written tiles', () async {
      final layersDir = Directory.systemTemp.createTempSync('tilewriter_stitch').path;
      final source = _syntheticPng(600, 300);
      final tiled = await writeTiles(bytes: source, layersDir: layersDir, name: 'stitchtest');

      final stitched = await stitchImage(
          layersDir: layersDir,
          fileTemplate: tiled.fileTemplate,
          width: tiled.width,
          height: tiled.height);

      expect(stitched, isNotNull);
      final original = img.decodeImage(source)!;
      final result = img.decodeImage(stitched!)!;
      expect(result.width, original.width);
      expect(result.height, original.height);
      for (var y = 0; y < original.height; y += 17) {
        for (var x = 0; x < original.width; x += 17) {
          expect(result.getPixel(x, y), original.getPixel(x, y));
        }
      }
    });

    test('returns null when a tile is missing (partial/mid-write state)', () async {
      final layersDir = Directory.systemTemp.createTempSync('tilewriter_missing').path;
      final tiled =
          await writeTiles(bytes: _syntheticPng(600, 300), layersDir: layersDir, name: 'partial');
      await File('$layersDir/partial_1000_1_0.png').delete();

      final stitched = await stitchImage(
          layersDir: layersDir,
          fileTemplate: tiled.fileTemplate,
          width: tiled.width,
          height: tiled.height);
      expect(stitched, isNull);
    });

    test('returns null for a non-tile file value or degenerate dimensions', () async {
      final layersDir = Directory.systemTemp.createTempSync('tilewriter_nontile').path;
      expect(
          await stitchImage(
              layersDir: layersDir, fileTemplate: 'plain.png', width: 100, height: 100),
          isNull);
      expect(
          await stitchImage(
              layersDir: layersDir,
              fileTemplate: 'x_{0}_{1}_{2}.png',
              width: 0,
              height: 100),
          isNull);
    });
  });

  test(
      'real round trip: tiles written into a real tempFolder survive '
      'saveComics -> reopen, pixel-identical to the source image', () async {
    final core = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('tilewriter_work').path);
    addTearDown(core.dispose);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened =
        await core.call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document = comicsFromCore(
      opened['comics'] as Map<String, dynamic>,
      samplePath,
      tempFolder: opened['tempFolder'] as String?,
    );
    expect(document.tempFolder, isNotNull);

    const width = 600, height = 300; // 2 cols x 1 row, edge-clipped
    final sourceBytes = _syntheticPng(width, height);
    final layersDir = '${document.tempFolder}/layers';
    final tiled = await writeTiles(bytes: sourceBytes, layersDir: layersDir, name: 'roundtriptest');

    // Point the first layer's first image slot at the new tiled artwork --
    // file comes from the UI model (comicsToCore merges it in), width/height
    // aren't UI-model fields so they're set directly on the raw JSON that
    // comicsToCore preserves as-is for keys _mergeImage doesn't touch.
    document.doc.layers.first.images.first.file = tiled.fileTemplate;
    (((document.raw['layers'] as List).first as Map)['images'] as List).first['width'] =
        tiled.width;
    (((document.raw['layers'] as List).first as Map)['images'] as List).first['height'] =
        tiled.height;

    final savedPath =
        '${Directory.systemTemp.createTempSync('tilewriter_saved').path}/roundtrip.comics';
    await core.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });

    final reopenCore = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('tilewriter_reopen').path);
    addTearDown(reopenCore.dispose);
    final reopened =
        await reopenCore.call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip = comicsFromCore(
      reopened['comics'] as Map<String, dynamic>,
      savedPath,
      tempFolder: reopened['tempFolder'] as String?,
    );

    final roundtripImage = roundtrip.doc.layers.first.images.first;
    expect(roundtripImage.file, tiled.fileTemplate);

    // Stitch the tiles back from the *reopened* tempFolder (proves the tiles
    // actually made it into the saved .comics zip, not just left on disk in
    // the original session) and compare pixel-for-pixel to the source.
    final reopenedLayersDir = '${roundtrip.tempFolder}/layers';
    final stitched = img.Image(width: width, height: height);
    final cols = (width / kTileSize).ceil();
    final rows = (height / kTileSize).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final tileFile = File('$reopenedLayersDir/roundtriptest_1000_${col}_$row.png');
        expect(tileFile.existsSync(), isTrue, reason: 'missing tile col=$col row=$row');
        final tile = img.decodeImage(tileFile.readAsBytesSync())!;
        for (var y = 0; y < tile.height; y++) {
          for (var x = 0; x < tile.width; x++) {
            final srcPixel = tile.getPixel(x, y);
            stitched.setPixelRgba(col * kTileSize + x, row * kTileSize + y, srcPixel.r,
                srcPixel.g, srcPixel.b, srcPixel.a);
          }
        }
      }
    }

    final original = img.decodeImage(sourceBytes)!;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final a = original.getPixel(x, y);
        final b = stitched.getPixel(x, y);
        expect(b.r, a.r, reason: 'r mismatch at ($x,$y)');
        expect(b.g, a.g, reason: 'g mismatch at ($x,$y)');
        expect(b.b, a.b, reason: 'b mismatch at ($x,$y)');
        expect(b.a, a.a, reason: 'a mismatch at ($x,$y)');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

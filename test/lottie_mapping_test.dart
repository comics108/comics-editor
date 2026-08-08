// tdd-dot-lottie-import-export, Plan Task 2.1-2.3: LottieDocument model +
// parse/write, pure Lottie JSON I/O with no .comics coupling. Real-fixture
// cases are skipped (not failed) when the fixture isn't present in this
// checkout, matching dataset_backward_compat_test.dart's own convention --
// samples/dataset/ are monorepo-only, not part of every clone of this repo.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/lottie_mapping.dart';

void main() {
  final repoRoot = Directory(Directory.current.path).parent.parent;
  final samplesDir = Directory('${repoRoot.path}/samples');
  final samplesAvailable = samplesDir.existsSync();

  group('parseLottieJson (pure, real fixtures)', () {
    final ashesFile = File(
      '${samplesDir.path}/sample_playback_viewport.lottie_unzip/ASHES_content/ASHES.json',
    );
    final ashesAvailable = ashesFile.existsSync();

    test('real ASHES.json parses: 720x1600, fr:60, 2 root precomp layers', () {
      final json = jsonDecode(ashesFile.readAsStringSync()) as Map<String, dynamic>;
      final doc = parseLottieJson(json);

      expect(doc.width, 720);
      expect(doc.height, 1600);
      expect(doc.frameRate, 60);
      expect(doc.layers, hasLength(2));
      expect(doc.layers.every((l) => l.type == LottieLayer.typePrecomp), isTrue);
      expect(doc.assets.length, greaterThan(100));
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('real ASHES.json root layers carry the confirmed sweep keyframes', () {
      final json = jsonDecode(ashesFile.readAsStringSync()) as Map<String, dynamic>;
      final doc = parseLottieJson(json);

      final allObjects1 = doc.layers.firstWhere((l) => l.name == 'All Objects1');
      final position = allObjects1.transform.position;
      expect(position.isAnimated, isTrue);
      expect(position.keyframes, hasLength(2));
      expect(position.keyframes!.first.value[1], 6496); // real Y start
      expect(position.keyframes!.last.value[1], -6500); // real Y end
    }, skip: ashesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    final chaseFile = File(
      '${repoRoot.path}/dataset/mahabharata/boranko/mahabharata-dot-lottie/unzip/'
      'Story 1/Book 1/3/THE CHASE_content/THE CHASE.json',
    );
    final chaseAvailable = chaseFile.existsSync();

    test('real THE CHASE.json: masks parse as static 4-vertex rectangles, mode "a"', () {
      final json = jsonDecode(chaseFile.readAsStringSync()) as Map<String, dynamic>;
      final doc = parseLottieJson(json);

      final maskedLayers = [
        for (final asset in doc.assets)
          if (asset.layers != null)
            for (final layer in asset.layers!)
              if (layer.mask != null) layer,
      ];
      expect(maskedLayers, hasLength(6)); // confirmed real count
      for (final layer in maskedLayers) {
        expect(layer.mask!.mode, 'a');
        expect(layer.mask!.vertices, hasLength(4));
        expect(layer.mask!.inverted, isFalse);
      }
    }, skip: chaseAvailable ? false : 'dataset/ not present in this checkout (monorepo-only fixture)');
  });

  group('parseLottieJson (error handling, F1)', () {
    test('missing required top-level keys throws LottieFormatException', () {
      expect(
        () => parseLottieJson({'v': '5.0.0'}),
        throwsA(isA<LottieFormatException>()),
      );
    });

    test('an unsupported layer type is flagged, not silently dropped or mis-typed', () {
      final doc = parseLottieJson({
        'v': '5.0.0', 'fr': 60.0, 'ip': 0.0, 'op': 100.0, 'w': 720, 'h': 1600,
        'layers': [
          {'ty': 4, 'nm': 'a shape layer', 'ks': <String, dynamic>{}},
          {'ty': 2, 'nm': 'an image layer', 'ks': <String, dynamic>{}},
        ],
      });
      expect(doc.layers[0].unsupportedReason, contains('shape layer'));
      expect(doc.layers[1].isSupported, isTrue);
    });

    test('solid (ty:1) and null (ty:3) layers get specific, named reasons, not "other"', () {
      final doc = parseLottieJson({
        'v': '5.0.0', 'fr': 60.0, 'ip': 0.0, 'op': 100.0, 'w': 720, 'h': 1600,
        'layers': [
          {'ty': 1, 'nm': 'a solid layer', 'ks': <String, dynamic>{}},
          {'ty': 3, 'nm': 'a null layer', 'ks': <String, dynamic>{}},
        ],
      });
      expect(doc.layers[0].unsupportedReason, contains('solid'));
      expect(doc.layers[1].unsupportedReason, contains('null'));
    });
  });

  group('parseLottieDocument / writeLottieDocument round-trip', () {
    test('a hand-built document round-trips through write -> parse', () {
      final original = LottieDocument(
        width: 720,
        height: 1600,
        frameRate: 60,
        inPoint: 0,
        outPoint: 100,
        name: 'root',
        contentBaseName: 'TEST',
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'layer_1',
            refId: 'image_0',
            inPoint: 0,
            outPoint: 100,
            transform: LottieTransform(
              position: LottieProperty.static(const [360, 800, 0]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: [
          LottieAsset(id: 'image_0', width: 100, height: 100, imagePath: 'images/img_0.png'),
        ],
      );

      final bytes = writeLottieDocument(
        original,
        assetFiles: [AssetFile('images/img_0.png', Uint8List.fromList([1, 2, 3]))],
      );
      final reparsed = parseLottieDocument(bytes);

      expect(reparsed.width, 720);
      expect(reparsed.height, 1600);
      expect(reparsed.frameRate, 60);
      expect(reparsed.contentBaseName, 'TEST');
      expect(reparsed.layers, hasLength(1));
      expect(reparsed.layers.single.name, 'layer_1');
      expect(reparsed.layers.single.transform.position.staticValue, [360, 800, 0]);
      expect(reparsed.assets.single.imagePath, 'images/img_0.png');
    });

    test('an animated property with easing round-trips through write -> parse', () {
      final original = LottieDocument(
        width: 720,
        height: 1600,
        frameRate: 60,
        inPoint: 0,
        outPoint: 100,
        contentBaseName: 'TEST',
        layers: [
          LottieLayer(
            type: LottieLayer.typeImage,
            name: 'layer_1',
            transform: LottieTransform(
              position: LottieProperty.animated([
                LottieKeyframe(
                  frame: 0,
                  value: const [0, 0, 0],
                  easeIn: (0.833, 0.833),
                  easeOut: (0.167, 0.167),
                ),
                LottieKeyframe(frame: 100, value: const [200, 0, 0]),
              ]),
              rotation: LottieProperty.static(const [0]),
              scale: LottieProperty.static(const [100, 100, 100]),
              opacity: LottieProperty.static(const [100]),
            ),
          ),
        ],
        assets: const [],
      );

      final bytes = writeLottieDocument(original, assetFiles: const []);
      final reparsed = parseLottieDocument(bytes);

      final position = reparsed.layers.single.transform.position;
      expect(position.isAnimated, isTrue);
      expect(position.keyframes, hasLength(2));
      expect(position.keyframes!.first.easeIn, (0.833, 0.833));
      expect(position.keyframes!.last.value, [200, 0, 0]);
    });

    test('a real .lottie zip (samples/sample.lottie) parses end-to-end', () {
      final bytes = File('${samplesDir.path}/sample.lottie').readAsBytesSync();
      final doc = parseLottieDocument(bytes);
      expect(doc.layers, isNotEmpty);
      expect(doc.width, greaterThan(0));
      expect(doc.height, greaterThan(0));
    }, skip: samplesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('real image assets are embedded data URIs, all fileFound == true', () {
      final bytes = File('${samplesDir.path}/sample.lottie').readAsBytesSync();
      final doc = parseLottieDocument(bytes);
      final imageAssets = doc.assets.where((a) => a.imagePath != null).toList();
      expect(imageAssets, isNotEmpty);
      expect(imageAssets.every((a) => a.imagePath!.startsWith('data:')), isTrue);
      expect(imageAssets.every((a) => a.fileFound == true), isTrue);
    }, skip: samplesAvailable ? false : 'samples/ not present in this checkout (monorepo-only fixture)');

    test('an external (non-embedded) image asset with no matching zip entry is fileFound == false', () {
      // No real content found uses external file references (both real
      // samples checked embed every image as a data URI) -- this exercises
      // the disclosed, untested-by-real-data code path directly instead.
      final original = LottieDocument(
        width: 720,
        height: 1600,
        frameRate: 60,
        inPoint: 0,
        outPoint: 100,
        contentBaseName: 'TEST',
        layers: const [],
        assets: [LottieAsset(id: 'image_0', width: 10, height: 10, imagePath: 'images/missing.png')],
      );
      final bytes = writeLottieDocument(original, assetFiles: const []); // no asset file provided
      final reparsed = parseLottieDocument(bytes);
      expect(reparsed.assets.single.fileFound, isFalse);
    });

    test('a corrupt zip throws LottieFormatException, not a generic crash (F1)', () {
      expect(
        () => parseLottieDocument(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<LottieFormatException>()),
      );
    });
  });
}

// Task 7.2 (flows/comics-ai/sdd-comics-ai-bhagavadgita-generator/03-plan.md): current-application
// (editor) validation of the Bhagavad Gita generator's real output, per 02-specifications.md's
// "Current application validation" section. Discovers `work/bhagavadgita/*.comics` (produced by
// the separate Python pipeline in apps/comics-ai/comics-ai-bhagavadgita-generator, not by this
// app), opens each through the real `DartIoCore` transport (same one used for iOS -- see its own
// doc comment: "Файлы, созданные этим ядром, совместимы с desktop/Android-ядром"), and checks
// dimensions/layer counts/no missing tile assets.
//
// Modeled directly on dataset_backward_compat_test.dart's real fixture-discovery/skip pattern:
// `work/` is a monorepo-root directory, not part of this app's own separate git history
// (apps/comics-editor-v2.9 pushes to its own repo whose tree never includes `work/`), so this
// whole file must degrade to a no-op (skipped, not crashed) when the fixture directory or its
// chapters are absent -- true for any checkout that only has this app's own repo, and true here
// until the full 18-chapter production run (Task 9.1) has been executed. Per Specifications:
// "the production-run verification command must point it at work/bhagavadgita/, where skipping is
// not accepted" -- that stronger guarantee is enforced procedurally, by actually running this
// suite against the real production output at Task 9.2's completion-proof step, not by code here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/dart_io_core.dart';

int _tileGridLength(int size) => (size / 512).ceil();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory(Directory.current.path).parent.parent;
  final fixtureDir = Directory('${repoRoot.path}/work/bhagavadgita');
  final fixtureAvailable = fixtureDir.existsSync();
  final chapterFiles = fixtureAvailable
      ? (fixtureDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.comics'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test(
    'sanity: work/bhagavadgita/ is reachable and has real generated chapters',
    () {
      expect(chapterFiles, isNotEmpty);
    },
    skip: fixtureAvailable
        ? false
        : 'work/bhagavadgita/ not present in this checkout -- run the generator '
              '(apps/comics-ai/comics-ai-bhagavadgita-generator/scripts/pipeline.py) first; '
              'see this file\'s header for why skipping here is acceptable but not at '
              'production-run verification time',
  );

  for (final file in chapterFiles) {
    final name = file.uri.pathSegments.last;
    test(
      '$name opens through DartIoCore with valid dimensions, layers, and no missing tile assets',
      () async {
        final temporaryDirectories = <Directory>[];
        Directory temporary(String prefix) {
          final directory = Directory.systemTemp.createTempSync(prefix);
          temporaryDirectories.add(directory);
          return directory;
        }

        try {
          final core = DartIoCore(workDirPath: temporary('bhagavadgita_work').path);
          final opened =
              await core.call('openComics', {'path': file.path}) as Map<String, dynamic>;
          final comics = opened['comics'] as Map<String, dynamic>;
          final tempFolder = opened['tempFolder'] as String;

          final width = (comics['width'] as num).toInt();
          final height = (comics['height'] as num).toInt();
          expect(width, greaterThan(0), reason: '$name: width must be positive');
          expect(height, greaterThan(0), reason: '$name: height must be positive');

          final layers = comics['layers'] as List;
          expect(layers, isNotEmpty, reason: '$name: expected at least one layer');

          for (final rawLayer in layers) {
            final layer = rawLayer as Map<String, dynamic>;
            final images = layer['images'] as List;
            expect(images.length, equals(3), reason: '$name: images[] must have 3 language slots');

            for (final rawImage in images) {
              final image = rawImage as Map<String, dynamic>;
              if (image.isEmpty) continue; // empty slot, nothing to check

              final fileTemplate = image['file'] as String;
              final imageWidth = (image['width'] as num).toInt();
              final imageHeight = (image['height'] as num).toInt();
              final stem = fileTemplate.replaceAll('_{0}_{1}_{2}.png', '');

              for (var col = 0; col < _tileGridLength(imageWidth); col++) {
                for (var row = 0; row < _tileGridLength(imageHeight); row++) {
                  final tilePath = '$tempFolder/layers/${stem}_1000_${col}_$row.png';
                  expect(
                    File(tilePath).existsSync(),
                    isTrue,
                    reason: '$name: missing tile asset $tilePath',
                  );
                }
              }
            }
          }
        } finally {
          for (final directory in temporaryDirectories.reversed) {
            if (directory.existsSync()) directory.deleteSync(recursive: true);
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

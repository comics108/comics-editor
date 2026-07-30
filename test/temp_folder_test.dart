// vdd-comics-editor-uiux-lettering, Task 2.1: openComics's tempFolder
// response field is threaded through into CoreDocument -- this is the
// working directory Phase 2's tile writer will write real image bytes
// into. Both real core implementations (the C# headless subprocess and the
// pure-Dart mobile fallback) already return it; this proves comicsFromCore
// no longer silently discards it, for both.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/core_client.dart';
import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CoreClient: tempFolder is a real directory with data.json and layers/', () async {
    final client = CoreClient();
    addTearDown(client.dispose);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened =
        await client.call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document = comicsFromCore(
      opened['comics'] as Map<String, dynamic>,
      samplePath,
      tempFolder: opened['tempFolder'] as String?,
    );

    expect(document.tempFolder, isNotNull);
    final dir = Directory(document.tempFolder!);
    expect(dir.existsSync(), isTrue);
    expect(File('${dir.path}/data.json').existsSync(), isTrue);
    expect(Directory('${dir.path}/layers').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('DartIoCore: tempFolder is a real directory with data.json and layers/', () async {
    final core = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('comics29tempfolder').path);
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
    final dir = Directory(document.tempFolder!);
    expect(dir.existsSync(), isTrue);
    expect(File('${dir.path}/data.json').existsSync(), isTrue);
    expect(Directory('${dir.path}/layers').existsSync(), isTrue);
  });

  test('comicsFromCore without tempFolder leaves it null (backward-compatible default)', () {
    final document = comicsFromCore({'width': 1080, 'height': 1920, 'layers': []}, '/tmp/x.comics');
    expect(document.tempFolder, isNull);
  });
}

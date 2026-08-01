// vdd-comics-editor-ai-uiux, Task 7.3: cross-device check. No real iOS/Android device or
// simulator is available in this environment, so a literal "cut on macOS, open on an iPad build"
// walkthrough can't be performed here -- disclosed rather than faked. What this test verifies
// instead, for real: a Cutting-produced .comics file (real regions, real accepted layers with
// `kind` set, produced via the exact same acceptRegion path the real app uses) round-trips
// correctly through DartIoCore -- the actual code path iOS/Android use instead of CoreClient
// (see comics_core.dart's createComicsCore()). This is the concrete, verifiable claim behind
// "layers a desktop cut produced appear normally on mobile": the file format and Layer.kind field
// are platform-agnostic, and DartIoCore reads/writes the identical data.json shape.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';
import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:comics_editor/src/ui/controller.dart';

Uint8List _samplePng() => Uint8List.fromList(img.encodePng(img.Image(width: 30, height: 20)));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 60; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a page cut on the desktop core (CoreClient) opens correctly via DartIoCore -- the actual '
      'iOS/Android code path -- with all kind-tagged layers intact', (tester) async {
    // "Cut on macOS": real desktop EditorController, real CoreClient (via openPath's default
    // createComicsCore(), which resolves to CoreClient on this host).
    final desktopController = EditorController();
    await tester.runAsync(() async {
      final opened = await desktopController.openPath('test/fixtures/sample.comics');
      if (!opened) {
        throw StateError('failed to open sample.comics: ${desktopController.coreError}');
      }
    });

    desktopController.cuttingClient = StubCuttingClient(
      stepDelay: Duration.zero,
      regions: [
        DetectedRegion(
          kind: 'character',
          confidence: 0.9,
          bbox: const Rect.fromLTWH(0, 0, 30, 20),
          cropPng: _samplePng(),
        ),
        DetectedRegion(
          kind: 'background',
          confidence: 0.95,
          bbox: const Rect.fromLTWH(0, 30, 30, 20),
          cropPng: _samplePng(),
        ),
      ],
    );
    await tester.runAsync(() async {
      desktopController.triggerCutting(_samplePng(), 0);
    });
    await _pumpUntil(tester, () => desktopController.cuttingSession?.completed == true);

    await tester.runAsync(() async {
      await desktopController.acceptRegion(0);
      await desktopController.acceptRegion(1);
    });

    final savedPath =
        '${Directory.systemTemp.createTempSync('cutting_cross_device_').path}/cut.comics';
    await tester.runAsync(() => desktopController.core
        .call('saveComics', {'path': savedPath, 'comics': comicsToCore(desktopController.coreDoc!)}));

    // "Open on an iPad/iPhone build": a real DartIoCore session (the actual mobile code path),
    // driven directly rather than through EditorController.openPath (which picks CoreClient vs
    // DartIoCore based on Platform.isIOS/isAndroid -- always false on this desktop test host, so
    // this constructs DartIoCore explicitly to exercise the real mobile parsing/zip logic).
    final mobileCore = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('cutting_cross_device_mobile_').path);
    addTearDown(mobileCore.dispose);
    final reopened = await tester.runAsync(
        () => mobileCore.call('openComics', {'path': savedPath})) as Map<String, dynamic>;
    final mobileDoc = comicsFromCore(
      reopened['comics'] as Map<String, dynamic>,
      savedPath,
      tempFolder: reopened['tempFolder'] as String?,
    );

    final kinds = mobileDoc.doc.layers.map((l) => l.kind).toList();
    expect(kinds, contains('character'));
    expect(kinds, contains('background'));
    // The tiles themselves must have actually made it into DartIoCore's own unpacked working
    // directory too, not just the JSON record referencing a filename that doesn't exist.
    final characterLayer = mobileDoc.doc.layers.firstWhere((l) => l.kind == 'character');
    final tileFile = File(
        '${mobileDoc.tempFolder}/layers/${characterLayer.images.first.file.replaceFirst('{0}', '1000').replaceFirst('{1}', '0').replaceFirst('{2}', '0')}');
    expect(tileFile.existsSync(), isTrue);
  });
}

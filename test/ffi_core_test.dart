// AOT-ворота (sdd-comics-editor-v2.9-android-ios, Task 1.4): FFI-путь через
// NativeAOT-библиотеку — тот же round-trip, что и у процессного ядра.
// Требует: tool/build_native.sh osx
@Tags(['core'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/ffi_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';

void main() {
  test('NativeAOT library is published', () {
    expect(FfiCore.resolveLibrary(), isNotNull,
        reason: 'Run tool/build_native.sh osx to publish the NativeAOT dylib');
  });

  test('FFI: open → edit → save → reopen round-trip on sample.comics', () async {
    final core = FfiCore();
    addTearDown(core.dispose);

    final ping = await core.call('ping') as Map<String, dynamic>;
    expect(ping['pong'], isTrue);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened =
        await core.call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document =
        comicsFromCore(opened['comics'] as Map<String, dynamic>, samplePath);

    // Главная проверка AOT: $type-анимации десериализовались (не пустой документ).
    expect(document.doc.width, 1080);
    expect(document.doc.height, 12000);
    expect(document.doc.layers, isNotEmpty);
    expect(document.doc.layers.first.anims, isNotEmpty);

    document.doc.height = 12002;
    final savedPath =
        '${Directory.systemTemp.createTempSync('comics29ffi').path}/roundtrip.comics';
    await core.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });

    final reopened =
        await core.call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip =
        comicsFromCore(reopened['comics'] as Map<String, dynamic>, savedPath);
    expect(roundtrip.doc.height, 12002);
    expect(roundtrip.doc.layers.length, document.doc.layers.length);
    expect(roundtrip.doc.sounds.length, document.doc.sounds.length);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

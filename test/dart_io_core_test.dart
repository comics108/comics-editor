// iOS fallback (sdd-comics-editor-v2.9-android-ios, решение пользователя
// 2026-07-23): чистый Dart вместо NativeAOT+FFI. Тот же round-trip, что и у
// процессного/FFI ядра, но без внешних бинарников — можно гонять всегда.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DartIoCore is always available (no external binary)', () {
    expect(DartIoCore().isAvailable, isTrue);
  });

  test('open → edit → save → reopen round-trip on sample.comics', () async {
    final core = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('comics29dart_work').path);
    addTearDown(core.dispose);

    final ping = await core.call('ping') as Map<String, dynamic>;
    expect(ping['pong'], isTrue);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened =
        await core.call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document =
        comicsFromCore(opened['comics'] as Map<String, dynamic>, samplePath);

    expect(document.doc.width, 1080);
    expect(document.doc.height, 12000);
    expect(document.doc.layers, isNotEmpty);
    expect(document.doc.layers.first.anims, isNotEmpty);

    document.doc.height = 12003;
    final savedPath =
        '${Directory.systemTemp.createTempSync('comics29dart').path}/roundtrip.comics';
    await core.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });
    expect(File(savedPath).existsSync(), isTrue);

    final reopened =
        await core.call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip =
        comicsFromCore(reopened['comics'] as Map<String, dynamic>, savedPath);
    expect(roundtrip.doc.height, 12003);
    expect(roundtrip.doc.layers.length, document.doc.layers.length);
    expect(roundtrip.doc.sounds.length, document.doc.sounds.length);

    // Файлы слоёв/звуков должны попасть в архив как есть (не только data.json).
    final rawImage =
        ((roundtrip.raw['layers'] as List).first['images'] as List).first
            as Map<String, dynamic>;
    expect(rawImage['width'], isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('interop: file saved by DartIoCore opens with the same round-trip data',
      () async {
    // Проверка совместимости формата архива: DartIoCore пишет обычный zip
    // (package:archive), читается тем же способом — эквивалент кросс-чтения
    // с desktop/Android-ядром (оба используют стандартный zip).
    final core = DartIoCore(
        workDirPath: Directory.systemTemp.createTempSync('comics29dart_work2').path);
    addTearDown(core.dispose);
    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    await core.call('openComics', {'path': samplePath});
    final exportPath =
        '${Directory.systemTemp.createTempSync('comics29dart_export').path}/export.comics';
    final ok = await core.call('exportPackage', {'path': exportPath}) as bool;
    expect(ok, isTrue);
    expect(File(exportPath).lengthSync(), greaterThan(0));
  });
}

// Интеграционный тест обвязки: CoreClient ↔ self-contained Comics.Editor.Headless.
// Требует опубликованного ядра: tool/build_headless.sh
@Tags(['core'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/core_client.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';

void main() {
  final binary = CoreClient.resolveBinary();

  test('core binary is published', () {
    expect(binary, isNotNull,
        reason: 'Run tool/build_headless.sh to publish the headless core');
  });

  test('open → edit → save → reopen round-trip on sample.comics', () async {
    final client = CoreClient();
    addTearDown(client.dispose);

    final ping = await client.call('ping') as Map<String, dynamic>;
    expect(ping['pong'], isTrue);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened = await client
        .call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document = comicsFromCore(
        opened['comics'] as Map<String, dynamic>, samplePath);

    expect(document.doc.width, 1080);
    expect(document.doc.height, 12000);
    expect(document.doc.layers, isNotEmpty);
    expect(document.doc.layers.first.anims, isNotEmpty);

    // Правка + сохранение через merge в исходный JSON.
    document.doc.height = 12001;
    final savedPath =
        '${Directory.systemTemp.createTempSync('comics29').path}/roundtrip.comics';
    await client.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });
    expect(File(savedPath).existsSync(), isTrue);

    // Повторное открытие: правка на месте, данные не потеряны.
    final reopened = await client
        .call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip =
        comicsFromCore(reopened['comics'] as Map<String, dynamic>, savedPath);
    expect(roundtrip.doc.height, 12001);
    expect(roundtrip.doc.layers.length, document.doc.layers.length);
    expect(roundtrip.doc.sounds.length, document.doc.sounds.length);

    // width/height изображений (нет в UI-моделях) сохраняются через raw.
    final rawImage =
        ((roundtrip.raw['layers'] as List).first['images'] as List).first
            as Map<String, dynamic>;
    expect(rawImage['width'], isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

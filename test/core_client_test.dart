// Интеграционный тест обвязки: CoreClient ↔ self-contained Comics.Editor.Headless.
// Требует опубликованного ядра: tool/build_headless.sh
@Tags(['core'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/core_client.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:comics_editor/src/i18n/language_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
      'kind/style/translations round-trip through the real headless core '
      'without disturbing untouched layers', () async {
    final client = CoreClient();
    addTearDown(client.dispose);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened = await client
        .call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document = comicsFromCore(
        opened['comics'] as Map<String, dynamic>, samplePath);
    final layerCount = document.doc.layers.length;
    expect(layerCount, greaterThan(1));

    final touched = document.doc.layers.first
      ..kind = 'balloon'
      ..style = 'speech';
    touched.translations['en'] = 'Hello';
    touched.translations['uk'] = 'Привіт';

    final savedPath =
        '${Directory.systemTemp.createTempSync('comics29kind').path}/roundtrip.comics';
    await client.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });

    // Fresh process/document, as in the real open flow -- proves this isn't
    // just an in-memory artifact of the same CoreDocument.
    final reopenClient = CoreClient();
    addTearDown(reopenClient.dispose);
    final reopened = await reopenClient
        .call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip =
        comicsFromCore(reopened['comics'] as Map<String, dynamic>, savedPath);

    expect(roundtrip.doc.layers.length, layerCount);
    final roundtripTouched = roundtrip.doc.layers.first;
    expect(roundtripTouched.kind, 'balloon');
    expect(roundtripTouched.style, 'speech');
    expect(roundtripTouched.translations, {'en': 'Hello', 'uk': 'Привіт'});

    // Every other layer must round-trip with no kind/style/translations key
    // at all -- the additive fields must not leak onto layers that never
    // set them.
    final rawLayers = roundtrip.raw['layers'] as List;
    for (var i = 1; i < rawLayers.length; i++) {
      final rawLayer = rawLayers[i] as Map<String, dynamic>;
      expect(rawLayer.containsKey('kind'), isFalse,
          reason: 'layer $i should have no kind key');
      expect(rawLayer.containsKey('style'), isFalse,
          reason: 'layer $i should have no style key');
      expect(rawLayer.containsKey('translations'), isFalse,
          reason: 'layer $i should have no translations key');
      expect(roundtrip.doc.layers[i].kind, isNull);
      expect(roundtrip.doc.layers[i].style, isNull);
      expect(roundtrip.doc.layers[i].translations, isEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
      'additive Images[] slot beyond en/ru/hi (Task 1.2) round-trips through '
      'the real headless core', () async {
    final registry = await LanguageRegistry.load();
    final client = CoreClient();
    addTearDown(client.dispose);

    final samplePath = '${Directory.current.path}/test/fixtures/sample.comics';
    final opened = await client
        .call('openComics', {'path': samplePath}) as Map<String, dynamic>;
    final document = comicsFromCore(
        opened['comics'] as Map<String, dynamic>, samplePath);

    final touched = document.doc.layers.first;
    final originalImageCount = touched.images.length;
    final ukIndex = registry.indexFor('uk')!;
    touched.imageSlotFor('uk', registry).file = 'uk_balloon.png';
    expect(touched.images.length, ukIndex + 1);
    expect(touched.images.length, greaterThan(originalImageCount));

    final savedPath =
        '${Directory.systemTemp.createTempSync('comics29slot').path}/roundtrip.comics';
    await client.call('saveComics', {
      'path': savedPath,
      'comics': comicsToCore(document),
    });

    final reopenClient = CoreClient();
    addTearDown(reopenClient.dispose);
    final reopened = await reopenClient
        .call('openComics', {'path': savedPath}) as Map<String, dynamic>;
    final roundtrip =
        comicsFromCore(reopened['comics'] as Map<String, dynamic>, savedPath);

    final roundtripTouched = roundtrip.doc.layers.first;
    expect(roundtripTouched.images.length, greaterThanOrEqualTo(ukIndex + 1));
    expect(roundtripTouched.imageSlotFor('uk', registry).file, 'uk_balloon.png');
    // en/ru/hi slots untouched by the extension.
    expect(roundtripTouched.imageSlotFor('en', registry).file,
        touched.imageSlotFor('en', registry).file);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

// vdd-comics-editor-uiux-lettering, Task 1.3: kind/style/translations are
// additive fields on Layer (see native/Comics.Editor/Models/Layer.cs) --
// these tests exercise the pure-Dart mapping layer directly (no core
// process needed) to prove both directions round-trip, and that a legacy
// layer with none of the three fields stays byte-identical (no stray keys).
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/models_mapping.dart';

Map<String, dynamic> _rawDoc(List<Map<String, dynamic>> layers) => {
      'width': 1080,
      'height': 1920,
      'layers': layers,
      'sounds': <dynamic>[],
    };

void main() {
  test('kind/style/translations read from raw JSON into EditorLayer', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
        'kind': 'balloon',
        'style': 'speech',
        'translations': {'en': 'Hello', 'uk': 'Привіт'},
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final layer = document.doc.layers.single;

    expect(layer.kind, 'balloon');
    expect(layer.style, 'speech');
    expect(layer.translations, {'en': 'Hello', 'uk': 'Привіт'});
  });

  test('legacy layer without kind/style/translations stays absent both ways', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final layer = document.doc.layers.single;
    expect(layer.kind, isNull);
    expect(layer.style, isNull);
    expect(layer.translations, isEmpty);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer.containsKey('kind'), isFalse);
    expect(mergedLayer.containsKey('style'), isFalse);
    expect(mergedLayer.containsKey('translations'), isFalse);
  });

  test('setting kind/style/translations on the UI layer merges back into raw JSON', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final layer = document.doc.layers.single
      ..kind = 'balloon'
      ..style = 'hand_lettered';
    layer.translations['en'] = 'Hi';
    layer.translations['ru'] = 'Привет';

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer['kind'], 'balloon');
    expect(mergedLayer['style'], 'hand_lettered');
    expect(mergedLayer['translations'], {'en': 'Hi', 'ru': 'Привет'});
  });

  test('clearing kind/style/translations removes the keys again', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
        'kind': 'balloon',
        'style': 'speech',
        'translations': {'en': 'Hello'},
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final layer = document.doc.layers.single
      ..kind = null
      ..style = null;
    layer.translations.clear();

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer.containsKey('kind'), isFalse);
    expect(mergedLayer.containsKey('style'), isFalse);
    expect(mergedLayer.containsKey('translations'), isFalse);
  });

  test('clone() deep-copies kind/style/translations independently', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
        'kind': 'balloon',
        'style': 'speech',
        'translations': {'en': 'Hello'},
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final original = document.doc.layers.single;
    final copy = original.clone();

    copy.kind = 'caption';
    copy.translations['en'] = 'Changed';
    copy.translations['fr'] = 'Bonjour';

    expect(original.kind, 'balloon');
    expect(original.translations, {'en': 'Hello'});
    expect(copy.kind, 'caption');
    expect(copy.translations, {'en': 'Changed', 'fr': 'Bonjour'});
  });

  // vdd-comics-editor-vertical-scroll, Task 1.1: legacy's Newtonsoft
  // serializer omits `end` whenever its true value is C#'s int default (0) --
  // exactly Layer.Create's seed TranslateAnim shape (Start=End=0, only Y
  // set). An absent `end` must round-trip as 0, not the historical 200
  // fallback (which was only ever correct for animations authored via
  // Anim.Add<T>'s Start+200 convention, which always writes `end` explicitly
  // and would never hit this fallback).
  test('animation with no end key parses as end=0 and stays keyless on save', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': [
          {'y': 1234}, // no $type (defaults to translate), no start, no end
        ],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final anim = document.doc.layers.single.anims.single;
    expect(anim.start, 0);
    expect(anim.end, 0);
    expect(anim.y, 1234);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedAnims = (mergedLayers.single as Map<String, dynamic>)['animations'] as List;
    final mergedAnim = mergedAnims.single as Map<String, dynamic>;
    expect(mergedAnim.containsKey('end'), isFalse);
  });
}

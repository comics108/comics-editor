// vdd-comics-editor-uiux-lettering, Task 1.3: kind/style/translations are
// additive fields on Layer (see native/Comics.Editor/Models/Layer.cs) --
// these tests exercise the pure-Dart mapping layer directly (no core
// process needed) to prove both directions round-trip, and that a legacy
// layer with none of the three fields stays byte-identical (no stray keys).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/models_mapping.dart';
import 'package:comics_editor/src/ui/models.dart';

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

  // tdd-dot-comics-format, Plan Task 5.3: basis/loop are new keys, not part
  // of the legacy C# Anim schema -- absent -> scroll/true.
  test('anim with no basis/loop key defaults to scroll/loop=true and stays keyless on save', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': [
          {'y': 10},
        ],
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final anim = document.doc.layers.single.anims.single;
    expect(anim.basis, AnimBasis.scroll);
    expect(anim.loop, isTrue);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedAnims = (mergedLayers.single as Map<String, dynamic>)['animations'] as List;
    final mergedAnim = mergedAnims.single as Map<String, dynamic>;
    expect(mergedAnim.containsKey('basis'), isFalse);
    expect(mergedAnim.containsKey('loop'), isFalse);
  });

  test('a time-basis, non-looping anim round-trips through raw JSON', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': [
          {'y': 10, 'basis': 'time', 'loop': false},
        ],
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final anim = document.doc.layers.single.anims.single;
    expect(anim.basis, AnimBasis.time);
    expect(anim.loop, isFalse);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedAnims = (mergedLayers.single as Map<String, dynamic>)['animations'] as List;
    final mergedAnim = mergedAnims.single as Map<String, dynamic>;
    expect(mergedAnim['basis'], 'time');
    expect(mergedAnim['loop'], false);
  });

  test('a time-basis, looping anim omits the loop key (default)', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': [
          {'y': 10, 'basis': 'time'},
        ],
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.layers.single.anims.single.loop, isTrue);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedAnims = (mergedLayers.single as Map<String, dynamic>)['animations'] as List;
    final mergedAnim = mergedAnims.single as Map<String, dynamic>;
    expect(mergedAnim.containsKey('loop'), isFalse);
  });

  // tdd-dot-comics-format, Plan Task 1.2: Layer.Id is a new additive field --
  // a legacy layer with no `id` key gets a fresh one generated at load time
  // (never left null), and a persisted `id` round-trips unchanged.
  test('layer with no id key gets a fresh generated id on load', () {
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
    expect(layer.id, isNotEmpty);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer['id'], layer.id);
  });

  test('persisted id round-trips unchanged', () {
    final raw = _rawDoc([
      {
        'id': 'existing-stable-id',
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final layer = document.doc.layers.single;
    expect(layer.id, 'existing-stable-id');

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer['id'], 'existing-stable-id');
  });

  // tdd-dot-comics-format, Plan Task 3.2: parentId is a new additive field,
  // same omit-if-absent pattern as kind/style.
  test('parentId read from raw JSON into EditorLayer', () {
    final raw = _rawDoc([
      {
        'id': 'parent-1',
        'images': [
          {'file': 'head.png'}
        ],
        'animations': <dynamic>[],
      },
      {
        'id': 'child-1',
        'parentId': 'parent-1',
        'images': [
          {'file': 'arm.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.layers[0].parentId, isNull);
    expect(document.doc.layers[1].parentId, 'parent-1');
  });

  test('legacy layer without parentId stays absent both ways', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.layers.single.parentId, isNull);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer.containsKey('parentId'), isFalse);
  });

  test('setting parentId on the UI layer merges back into raw JSON', () {
    final raw = _rawDoc([
      {
        'images': [
          {'file': 'bg.png'}
        ],
        'animations': <dynamic>[],
      },
    ]);

    final document = comicsFromCore(raw, '/tmp/doc.comics');
    document.doc.layers.single.parentId = 'some-parent-id';

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer['parentId'], 'some-parent-id');
  });

  // tdd-dot-comics-format, Plan Task 2.2: scrollType/preferredOrientation
  // are new additive doc-level fields, absent -> the backward-compat
  // default (vertical/portrait).
  test('legacy doc without scrollType/preferredOrientation defaults to vertical/portrait', () {
    final raw = _rawDoc([]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.scrollType, ScrollType.vertical);
    expect(document.doc.preferredOrientation, PreferredOrientation.portrait);
  });

  test('scrollType/preferredOrientation read from raw JSON', () {
    final raw = {..._rawDoc([]), 'scrollType': 'horizontal', 'preferredOrientation': 'auto'};
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.scrollType, ScrollType.horizontal);
    expect(document.doc.preferredOrientation, PreferredOrientation.auto);
  });

  test('scrollType/preferredOrientation round-trip through comicsToCore', () {
    final raw = _rawDoc([]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    document.doc.scrollType = ScrollType.horizontal;
    document.doc.preferredOrientation = PreferredOrientation.landscape;

    final merged = comicsToCore(document);
    expect(merged['scrollType'], 'horizontal');
    expect(merged['preferredOrientation'], 'landscape');
  });

  // tdd-dot-comics-format, Plan Task 4.2: solidColor/mask are new additive
  // fields, same omit-if-absent pattern as kind/style/parentId.
  test('solidColor read from raw JSON into EditorLayer', () {
    final raw = _rawDoc([
      {
        'images': <dynamic>[],
        'animations': <dynamic>[],
        'solidColor': '#ffffff',
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.layers.single.solidColor, '#ffffff');
  });

  test('legacy layer without solidColor/mask stays absent both ways', () {
    final raw = _rawDoc([
      {
        'images': <dynamic>[],
        'animations': <dynamic>[],
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    expect(document.doc.layers.single.solidColor, isNull);
    expect(document.doc.layers.single.mask, isNull);

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer.containsKey('solidColor'), isFalse);
    expect(mergedLayer.containsKey('mask'), isFalse);
  });

  test('a real THE BROKEN TUSK-shaped solid layer round-trips exactly', () {
    // Real fields found in THE BROKEN TUSK.json: sc:"#ffffff", sw:720, sh:27326.
    final raw = _rawDoc([
      {
        'images': <dynamic>[],
        'animations': <dynamic>[],
        'solidColor': '#ffffff',
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final merged = comicsToCore(document)['layers'] as List;
    expect((merged.single as Map)['solidColor'], '#ffffff');
  });

  test('rect mask reads/writes through raw JSON', () {
    final raw = _rawDoc([
      {
        'images': <dynamic>[],
        'animations': <dynamic>[],
        'mask': {
          'shape': 'rect',
          'rect': {'x': 10.0, 'y': 20.0, 'w': 100.0, 'h': 50.0},
        },
      },
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    final mask = document.doc.layers.single.mask!;
    expect(mask.shape, 'rect');
    expect(mask.rect, const Rect.fromLTWH(10, 20, 100, 50));

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedMask = (mergedLayers.single as Map)['mask'] as Map;
    expect(mergedMask['shape'], 'rect');
    expect(mergedMask['rect'], {'x': 10.0, 'y': 20.0, 'w': 100.0, 'h': 50.0});
  });

  test('setting solidColor/mask on the UI layer merges back into raw JSON', () {
    final raw = _rawDoc([
      {'images': <dynamic>[], 'animations': <dynamic>[]},
    ]);
    final document = comicsFromCore(raw, '/tmp/doc.comics');
    document.doc.layers.single
      ..solidColor = '#123456'
      ..mask = LayerMask.rect(const Rect.fromLTWH(0, 0, 10, 10));

    final mergedLayers = comicsToCore(document)['layers'] as List;
    final mergedLayer = mergedLayers.single as Map<String, dynamic>;
    expect(mergedLayer['solidColor'], '#123456');
    expect(mergedLayer['mask'], isNotNull);
  });
}

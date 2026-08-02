import 'dart:io';
import 'dart:ui';

import '../ui/models.dart';

/// Конвертация между JSON ядра (data.json редактора: camelCase,
/// TypeNameHandling.Auto — `$type` на подклассах Anim) и view-моделями макета.
///
/// UI-модели хранят не все поля формата (например, width/height изображений),
/// поэтому исходный JSON сохраняется рядом с документом ([CoreDocument.raw])
/// и при сохранении редактируемые поля вливаются обратно в него — данные,
/// не представленные в UI, не теряются.
class CoreDocument {
  CoreDocument(this.doc, this.raw, this.path, {this.tempFolder});

  final ComicsDoc doc;
  final Map<String, dynamic> raw;
  String path;

  /// vdd-comics-editor-uiux-lettering, Task 2.1: the core's working directory
  /// for this open document (`openComics`'s `tempFolder` response field, same
  /// value `ping` returns) -- where `layers/*.png` tiles actually live on
  /// disk between `openComics` and `saveComics`. Null only for documents with
  /// no backing core session (e.g. [ComicsDoc.clone] snapshots).
  String? tempFolder;
}

const _typePrefix = 'Comics.Editor.Models.';
const _typeSuffix = ', Comics.Editor';

AnimType? _animTypeFromDollarType(String? dollarType) {
  if (dollarType == null) return null;
  switch (dollarType) {
    case '${_typePrefix}TranslateAnim$_typeSuffix':
      return AnimType.translate;
    case '${_typePrefix}RotateAnim$_typeSuffix':
      return AnimType.rotate;
    case '${_typePrefix}ScaleAnim$_typeSuffix':
      return AnimType.scale;
    case '${_typePrefix}AlphaAnim$_typeSuffix':
      return AnimType.alpha;
    case '${_typePrefix}SoundAnim$_typeSuffix':
      return AnimType.sound;
  }
  return null;
}

String _dollarTypeFromAnimType(AnimType type) {
  final name = switch (type) {
    AnimType.translate => 'TranslateAnim',
    AnimType.rotate => 'RotateAnim',
    AnimType.scale => 'ScaleAnim',
    AnimType.alpha => 'AlphaAnim',
    AnimType.sound => 'SoundAnim',
  };
  return '$_typePrefix$name$_typeSuffix';
}

double _asDouble(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

int _asInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.round() : fallback;

Anim _animFromJson(Map<String, dynamic> json, {AnimType fallback = AnimType.translate}) {
  final type = _animTypeFromDollarType(json[r'$type'] as String?) ?? fallback;
  final anim = Anim(type,
      start: _asInt(json['start']), end: _asInt(json['end']));
  anim.x = _asDouble(json['x']);
  anim.y = _asDouble(json['y']);
  anim.angle = _asDouble(json['angle']);
  anim.scaleX = _asDouble(json['scaleX'], 1);
  anim.scaleY = _asDouble(json['scaleY'], 1);
  anim.pivotX = _asDouble(json['pivotX']);
  anim.pivotY = _asDouble(json['pivotY']);
  anim.alpha = _asDouble(json['alpha'], 1);
  return anim;
}

Map<String, dynamic> _animToJson(Anim anim) {
  // DefaultValueHandling.Ignore на стороне ядра: нулевые значения опускаем,
  // как это делает исходная сериализация.
  final json = <String, dynamic>{r'$type': _dollarTypeFromAnimType(anim.type)};
  void put(String key, num value, [num defaultValue = 0]) {
    if (value != defaultValue) json[key] = value;
  }

  // vdd-comics-editor-uiux-lettering, Task 7.1: found via the real-dataset
  // backward-compat pass -- every Anim subclass on the C# side overrides a
  // read-only `Type` (AnimTypes enum) property, which Newtonsoft still
  // serializes (DefaultValueHandling.Ignore only omits it when the value
  // equals default(AnimTypes), i.e. Translate == 0 -- so only TranslateAnim
  // entries genuinely lack this key; Rotate/Scale/Alpha/Sound all have it).
  // It's redundant with `$type` for deserialization (never read back here,
  // same as the C# side never needs to since the value can't be set), but
  // omitting it on write meant re-saving silently dropped a real field from
  // any non-translate animation. AnimTypes' C# declaration order
  // (Translate/Rotate/Scale/Alpha/Sound) matches AnimType's Dart order
  // exactly, so `.index` is the right wire value with no lookup table.
  put('type', anim.type.index);
  put('start', anim.start);
  // vdd-comics-editor-vertical-scroll, Task 1.1: `end` genuinely defaults to
  // 0 on the C# side (Newtonsoft's DefaultValueHandling.Ignore compares
  // against default(int)=0, same as `start`) -- Layer.Create's seed
  // TranslateAnim is exactly this case (Start=End=0, only Y set). An earlier
  // version of this code used a 200 fallback here (matching a since-removed
  // 200 default on _animFromJson's read side, put in place for an unrelated
  // reason -- see git history), which round-tripped consistently but meant
  // every legacy-authored resting keyframe was silently misread as a 200px
  // slide-in the moment interpolation started being evaluated. Both sides
  // must keep matching (now 0/0) or re-saves would drift real user data.
  put('end', anim.end);
  switch (anim.type) {
    case AnimType.translate:
      put('x', anim.x.round());
      put('y', anim.y.round());
    case AnimType.rotate:
      put('angle', anim.angle);
      put('pivotX', anim.pivotX);
      put('pivotY', anim.pivotY);
    case AnimType.scale:
      // vdd-comics-editor-uiux-lettering, Task 7.1: same class of bug as
      // `end`/`type` above -- DefaultValueHandling.Ignore on the C# side
      // compares against default(double) == 0, not the app's "new anim"
      // initial value of 1 (no [DefaultValue] attribute on ScaleX/ScaleY to
      // override that). A scale anim explicitly at 1.0 (full scale, an
      // extremely common real value) was being wrongly treated as "default,
      // omit" here and silently dropped from re-saved JSON. The parse side
      // (_animFromJson's `_asDouble(json['scaleX'], 1)`) is correct as-is
      // and unrelated to this: it mirrors the C# object's Init()-assigned
      // value of 1, which deserialization leaves untouched when the key is
      // genuinely absent -- Newtonsoft only overwrites properties actually
      // present in the incoming JSON.
      put('scaleX', anim.scaleX);
      put('scaleY', anim.scaleY);
      put('pivotX', anim.pivotX);
      put('pivotY', anim.pivotY);
    case AnimType.alpha:
      // Same fix as scaleX/scaleY above -- default(double) == 0 on the C#
      // side, not the app's "new anim" initial value of 1.
      put('alpha', anim.alpha);
    case AnimType.sound:
      break;
  }
  return json;
}

/// core JSON → документ макета (+ исходный JSON сохраняется в [CoreDocument.raw]).
CoreDocument comicsFromCore(Map<String, dynamic> raw, String path, {String? tempFolder}) {
  final name = path.split(Platform.pathSeparator).last;
  final isPuzzle = name.endsWith('.puzzle');
  final doc = ComicsDoc(
    name: name,
    type: isPuzzle ? DocType.puzzle : DocType.comics,
    width: _asInt(raw['width'], 1080),
    height: _asInt(raw['height'], 2160),
  );

  for (final layerJson in (raw['layers'] as List? ?? const [])) {
    final layer = layerJson as Map<String, dynamic>;
    final images = (layer['images'] as List? ?? const []);
    final firstFile = images.isNotEmpty
        ? ((images.first as Map<String, dynamic>)['file'] as String? ?? '')
        : '';
    final uiLayer = EditorLayer(firstFile.isEmpty ? 'layer' : firstFile)
      ..preview = layer['preview'] == true
      ..kind = layer['kind'] as String?
      ..style = layer['style'] as String?;
    final translations = layer['translations'] as Map?;
    if (translations != null) {
      translations.forEach((key, value) {
        uiLayer.translations[key as String] = value as String? ?? '';
      });
    }
    uiLayer.images.clear();
    for (final imageJson in images) {
      final image = imageJson as Map<String, dynamic>;
      uiLayer.images.add(LayerImage(
        file: image['file'] as String? ?? '',
        popup: image['popup'] as String? ?? '',
      ));
    }
    while (uiLayer.images.length < kLangs.length) {
      uiLayer.images.add(LayerImage());
    }
    uiLayer.anims.clear();
    for (final animJson in (layer['animations'] as List? ?? const [])) {
      uiLayer.anims.add(_animFromJson(animJson as Map<String, dynamic>));
    }
    for (final anim in uiLayer.anims) {
      if (anim.type == AnimType.translate) {
        uiLayer.translate = Offset(anim.x, anim.y);
        break;
      }
    }
    doc.layers.add(uiLayer);
  }

  for (final soundJson in (raw['sounds'] as List? ?? const [])) {
    final sound = soundJson as Map<String, dynamic>;
    final uiSound = EditorSound(sound['file'] as String? ?? '');
    uiSound.anims.clear();
    for (final animJson in (sound['animations'] as List? ?? const [])) {
      uiSound.anims
          .add(_animFromJson(animJson as Map<String, dynamic>, fallback: AnimType.sound));
    }
    doc.sounds.add(uiSound);
  }

  return CoreDocument(doc, raw, path, tempFolder: tempFolder);
}

/// vdd-comics-editor-uiux-lettering, Task 2.3: width/height aren't part of
/// the UI model (see [CoreDocument]'s doc comment -- they're format fields
/// the UI never edits, preserved via [CoreDocument.raw] as-is). A caller
/// that just wrote a brand-new tiled image (Task 2.2) has real pixel
/// dimensions that must land in the JSON directly, since [comicsToCore]'s
/// merge only ever touches `file`/`popup`. Grows `raw['layers']` and the
/// target layer's `images` list as needed so this works for a slot Task 1.2
/// just extended [EditorLayer.images] with, not only pre-existing ones.
void setImageDimensions(
    CoreDocument document, int layerIndex, int imageIndex, int width, int height) {
  final rawLayers = ((document.raw['layers'] as List?) ?? <dynamic>[]).toList();
  while (rawLayers.length <= layerIndex) {
    rawLayers.add(<String, dynamic>{});
  }
  final rawLayer = Map<String, dynamic>.from(rawLayers[layerIndex] as Map? ?? {});

  final rawImages = ((rawLayer['images'] as List?) ?? <dynamic>[]).toList();
  while (rawImages.length <= imageIndex) {
    rawImages.add(<String, dynamic>{});
  }
  final rawImage = Map<String, dynamic>.from(rawImages[imageIndex] as Map? ?? {});
  rawImage['width'] = width;
  rawImage['height'] = height;
  rawImages[imageIndex] = rawImage;

  rawLayer['images'] = rawImages;
  rawLayers[layerIndex] = rawLayer;
  document.raw['layers'] = rawLayers;
}

/// vdd-comics-editor-uiux-lettering, Task 4.2: read counterpart to
/// [setImageDimensions] -- the balloon editor card's artwork preview needs
/// real width/height to stitch tiles (`stitchImage` in `tile_writer.dart`),
/// which live only in [CoreDocument.raw]. Returns null if the layer/slot
/// isn't present or has no recorded dimensions.
({int width, int height})? imageDimensions(
    CoreDocument document, int layerIndex, int imageIndex) {
  final rawLayers = document.raw['layers'] as List?;
  if (rawLayers == null || layerIndex < 0 || layerIndex >= rawLayers.length) return null;
  final rawImages = (rawLayers[layerIndex] as Map)['images'] as List?;
  if (rawImages == null || imageIndex < 0 || imageIndex >= rawImages.length) return null;
  final rawImage = rawImages[imageIndex] as Map;
  final width = (rawImage['width'] as num?)?.toInt();
  final height = (rawImage['height'] as num?)?.toInt();
  if (width == null || height == null) return null;
  return (width: width, height: height);
}

/// Вливает редактируемые поля документа обратно в исходный JSON ядра.
Map<String, dynamic> comicsToCore(CoreDocument document) {
  final doc = document.doc;
  final raw = Map<String, dynamic>.from(document.raw);
  raw['width'] = doc.width;
  raw['height'] = doc.height;

  final rawLayers = (document.raw['layers'] as List? ?? const []);
  raw['layers'] = [
    for (var i = 0; i < doc.layers.length; i++)
      _mergeLayer(
        doc.layers[i],
        i < rawLayers.length
            ? Map<String, dynamic>.from(rawLayers[i] as Map)
            : <String, dynamic>{},
      ),
  ];

  final rawSounds = (document.raw['sounds'] as List? ?? const []);
  raw['sounds'] = [
    for (var i = 0; i < doc.sounds.length; i++)
      _mergeSound(
        doc.sounds[i],
        i < rawSounds.length
            ? Map<String, dynamic>.from(rawSounds[i] as Map)
            : <String, dynamic>{},
      ),
  ];
  return raw;
}

Map<String, dynamic> _mergeLayer(EditorLayer layer, Map<String, dynamic> raw) {
  if (layer.preview) {
    raw['preview'] = true;
  } else {
    raw.remove('preview');
  }

  // vdd-comics-editor-uiux-lettering: additive fields, mirror Layer.cs's
  // DefaultValueHandling.Ignore — omit the key entirely when unset/empty
  // rather than writing null/{} so legacy layers stay byte-identical.
  if (layer.kind != null && layer.kind!.isNotEmpty) {
    raw['kind'] = layer.kind;
  } else {
    raw.remove('kind');
  }
  if (layer.style != null && layer.style!.isNotEmpty) {
    raw['style'] = layer.style;
  } else {
    raw.remove('style');
  }
  if (layer.translations.isNotEmpty) {
    raw['translations'] = Map<String, String>.from(layer.translations);
  } else {
    raw.remove('translations');
  }

  final rawImages = (raw['images'] as List? ?? const []);
  raw['images'] = [
    for (var i = 0; i < layer.images.length; i++)
      _mergeImage(
        layer.images[i],
        i < rawImages.length
            ? Map<String, dynamic>.from(rawImages[i] as Map)
            : <String, dynamic>{},
      ),
  ];
  raw['animations'] = [for (final anim in layer.anims) _animToJson(anim)];
  return raw;
}

Map<String, dynamic> _mergeImage(LayerImage image, Map<String, dynamic> raw) {
  // width/height и прочие поля формата сохраняются из raw как есть.
  if (image.file.isNotEmpty) {
    raw['file'] = image.file;
  } else {
    raw.remove('file');
  }
  if (image.popup.isNotEmpty) {
    raw['popup'] = image.popup;
  } else {
    raw.remove('popup');
  }
  return raw;
}

Map<String, dynamic> _mergeSound(EditorSound sound, Map<String, dynamic> raw) {
  if (sound.file.isNotEmpty) raw['file'] = sound.file;
  raw['animations'] = [for (final anim in sound.anims) _animToJson(anim)];
  return raw;
}

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
  CoreDocument(this.doc, this.raw, this.path);

  final ComicsDoc doc;
  final Map<String, dynamic> raw;
  String path;
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
      start: _asInt(json['start']), end: _asInt(json['end'], 200));
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

  put('start', anim.start);
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
      put('scaleX', anim.scaleX, 1);
      put('scaleY', anim.scaleY, 1);
      put('pivotX', anim.pivotX);
      put('pivotY', anim.pivotY);
    case AnimType.alpha:
      put('alpha', anim.alpha, 1);
    case AnimType.sound:
      break;
  }
  return json;
}

/// core JSON → документ макета (+ исходный JSON сохраняется в [CoreDocument.raw]).
CoreDocument comicsFromCore(Map<String, dynamic> raw, String path) {
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
      ..preview = layer['preview'] == true;
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

  return CoreDocument(doc, raw, path);
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

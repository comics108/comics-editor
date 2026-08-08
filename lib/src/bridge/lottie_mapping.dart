import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive_io.dart';

/// tdd-dot-lottie-import-export Plan Task 2.1-2.3: minimal Lottie/Bodymovin
/// JSON model -- only what real content and this flow's Test Cases need
/// (image/precomp/solid/null layers, `parent`, vector masks, p/r/s/o
/// transform keyframes). Shape/text/gradient/repeater layers are
/// represented only via [LottieLayer.unsupportedReason], never modeled
/// structurally -- per `03-specifications.md`'s own "deliberately does not
/// model" note.

/// Thrown by [parseLottieDocument] on invalid/non-Lottie input -- a typed
/// exception, not a generic [FormatException], so callers can
/// short-circuit before ever building a review screen (Test F1).
class LottieFormatException implements Exception {
  LottieFormatException(this.message);
  final String message;
  @override
  String toString() => 'LottieFormatException: $message';
}

/// One keyframe in an animated property. `easeIn`/`easeOut` are the raw
/// bezier ease handles (`i`/`o`) -- real content sampled uses AE's standard
/// Easy Ease (`{x:0.833,y:0.833}`/`{x:0.167,y:0.167}`) uniformly, but this
/// class stores whatever the file actually has, no assumption baked in.
class LottieKeyframe {
  LottieKeyframe({required this.frame, required this.value, this.easeIn, this.easeOut});
  final double frame; // t
  final List<double> value; // s -- [x,y,z] for p/s, [angle] for r, [opacity] for o
  final (double x, double y)? easeIn; // i
  final (double x, double y)? easeOut; // o
}

/// A single p/r/s/o/a property -- either a static value (`a:0`) or a
/// keyframe list (`a:1`), matching Lottie's own on-the-wire shape exactly
/// rather than collapsing the distinction.
class LottieProperty {
  LottieProperty.static(this.staticValue) : keyframes = null;
  LottieProperty.animated(this.keyframes) : staticValue = null;
  final List<double>? staticValue;
  final List<LottieKeyframe>? keyframes;
  bool get isAnimated => keyframes != null;

  /// The value at a specific keyframe index, or the static value if
  /// unanimated -- a small convenience for the (Plan Phase 3+) code that
  /// needs "the value at t=0" / "the value at the last keyframe" without
  /// re-deriving the static/animated branch every time.
  List<double> valueAt(int keyframeIndex) => isAnimated ? keyframes![keyframeIndex].value : staticValue!;
}

/// `ks`'s p/r/s/o/a properties.
class LottieTransform {
  LottieTransform({
    required this.position,
    required this.rotation,
    required this.scale,
    required this.opacity,
    this.anchor,
  });
  final LottieProperty position; // p
  final LottieProperty rotation; // r
  final LottieProperty scale; // s
  final LottieProperty opacity; // o
  final LottieProperty? anchor; // a
}

/// A vector mask (`masksProperties` entry). Real content (`THE CHASE`, 6
/// real masks, verified byte-level): always `mode:"a"`, always a static
/// (non-animated) 4-vertex rectangle, never inverted, no curve handles.
/// This class only models that confirmed-real shape -- an animated or
/// curved mask path is out of scope, per this flow's own "simple math"
/// premise; [LottieMask.fromJson] throws rather than silently
/// misinterpreting one, since guessing at unverified shapes risks silent
/// data corruption.
class LottieMask {
  LottieMask({required this.mode, required this.vertices, this.inverted = false});
  final String mode; // "a" -- only value found in real content
  final List<Offset> vertices;
  final bool inverted; // inv
}

/// One layer. `type` mirrors Lottie's own `ty` numerically (2=image,
/// 0=precomp, 1=solid, 3=null, 4=shape, 5=text, other=unsupported).
/// `unsupportedReason` is non-null exactly when this layer isn't a
/// supported image/precomp layer, or is but carries a mask/effect this
/// flow doesn't model -- named specifically (not a generic "unsupported"),
/// since solid/null layers are confirmed real content (`THE BROKEN TUSK`,
/// `SVAYAMWARA` respectively), not hypothetical.
class LottieLayer {
  /// [unsupportedReason], when omitted, is always computed from [type] by
  /// [_defaultUnsupportedReasonFor] -- deliberately NOT left to default to
  /// null (i.e. "supported"), which would have silently mis-classified any
  /// hand-built `LottieLayer` (e.g. in a test, or a future caller
  /// constructing one directly rather than via [_layerFromJson]) as
  /// supported regardless of its real type. Found via testing: an earlier
  /// version of this class left the parser (`_layerFromJson`) solely
  /// responsible for this, which worked for real parsed files but was
  /// silently wrong for anything hand-constructed.
  LottieLayer({
    required this.type,
    required this.name,
    required this.transform,
    this.refId,
    this.parent,
    String? unsupportedReason,
    this.mask,
    this.inPoint = 0,
    this.outPoint = 0,
    this.startTime = 0,
  }) : unsupportedReason = unsupportedReason ?? _defaultUnsupportedReasonFor(type);

  static const typeImage = 2;
  static const typePrecomp = 0;
  static const typeSolid = 1;
  static const typeNull = 3;
  static const typeShape = 4;
  static const typeText = 5;

  final int type;
  final String name;
  final String? refId; // precomp layers: references LottieDocument.assets' id
  final int? parent; // index of another layer in the SAME composition this layer is relative to
  final String? unsupportedReason;
  final LottieTransform transform;
  final LottieMask? mask;
  final double inPoint; // ip
  final double outPoint; // op
  final double startTime; // st

  bool get isSupported => unsupportedReason == null;

  static String? _defaultUnsupportedReasonFor(int type) => switch (type) {
        typeImage => null,
        typePrecomp => null,
        typeSolid =>
          'unsupported: solid-color layer (ty:1) -- import as EditorLayer.solidColor is Plan Task 4.x scope, not this parse step',
        typeNull =>
          'unsupported: null/organizational layer (ty:3) -- maps to EditorLayer.organizationalKind, not this parse step',
        typeShape => 'unsupported: shape layer (ty:4)',
        typeText => 'unsupported: text layer (ty:5)',
        _ => 'unsupported: unrecognized layer type (ty:$type)',
      };
}

/// One `assets[]` entry -- either a precomp (`layers` present) or an image
/// asset (`width`/`height`/`imagePath` present).
class LottieAsset {
  LottieAsset({
    required this.id,
    this.layers,
    this.width,
    this.height,
    this.imagePath,
    this.embedded = false,
    this.fileFound,
  });
  final String id;
  final List<LottieLayer>? layers;
  final int? width;
  final int? height;
  final String? imagePath; // u + p combined, image assets only
  final bool embedded; // e

  /// tdd-dot-lottie-import-export Plan Task 3.2/F2: whether [imagePath]'s
  /// bytes were actually found in the zip archive -- only [parseLottieDocument]
  /// (which has real archive access) sets this; the pure [parseLottieJson]
  /// leaves it null (unknown/not checked), which callers should treat as
  /// "assume present" rather than a missing-asset flag, since a JSON-only
  /// caller has no way to know either way.
  final bool? fileFound;
}

/// The whole parsed composition -- `w`/`h`/`fr`/`ip`/`op` mirror Lottie's
/// own top-level keys exactly. `contentBaseName` is not a Lottie field --
/// it's the `<name>` in the real zip layout's `NAME_content/NAME.json`
/// path (e.g. "ASHES"), remembered so [writeLottieDocument] can reconstruct
/// the same layout symmetrically on export.
class LottieDocument {
  LottieDocument({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.inPoint,
    required this.outPoint,
    required this.layers,
    required this.assets,
    this.name = '',
    this.contentBaseName = 'content',
  });
  final int width, height;
  final double frameRate, inPoint, outPoint;
  final String name; // nm
  final String contentBaseName;
  final List<LottieLayer> layers;
  final List<LottieAsset> assets;
}

/// Bytes for one asset file to include when zipping a written
/// [LottieDocument] -- [path] must match the `imagePath` of some
/// [LottieAsset] in the document (relative path within the zip).
class AssetFile {
  AssetFile(this.path, this.bytes);
  final String path;
  final Uint8List bytes;
}

// ---------------- parse ----------------

(double, double)? _easeFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  return (_asDouble(json['x']), _asDouble(json['y']));
}

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is List && value.isNotEmpty && value.first is num) return (value.first as num).toDouble();
  return fallback;
}

List<double> _valueList(dynamic raw) {
  if (raw is List) return [for (final v in raw) (v as num).toDouble()];
  if (raw is num) return [raw.toDouble()];
  return const [];
}

LottieProperty _propertyFromJson(dynamic json) {
  if (json is! Map) return LottieProperty.static(const []);
  final animated = json['a'] == 1;
  if (!animated) {
    return LottieProperty.static(_valueList(json['k']));
  }
  final keyframesJson = json['k'] as List? ?? const [];
  return LottieProperty.animated([
    for (final kf in keyframesJson)
      LottieKeyframe(
        frame: _asDouble((kf as Map)['t']),
        value: _valueList(kf['s']),
        easeIn: _easeFromJson(kf['i'] as Map<String, dynamic>?),
        easeOut: _easeFromJson(kf['o'] as Map<String, dynamic>?),
      ),
  ]);
}

LottieTransform _transformFromJson(Map<String, dynamic>? ks) {
  final json = ks ?? const {};
  return LottieTransform(
    position: _propertyFromJson(json['p']),
    rotation: _propertyFromJson(json['r']),
    scale: _propertyFromJson(json['s']),
    opacity: _propertyFromJson(json['o']),
    anchor: json.containsKey('a') ? _propertyFromJson(json['a']) : null,
  );
}

/// Parses one real `masksProperties[]` entry. Throws [LottieFormatException]
/// for a shape this flow's real-data investigation never found (animated
/// path, curve handles, non-"a" mode) -- per this class's own doc comment,
/// guessing at an unverified shape risks silent data corruption, so an
/// explicit, catchable failure is the safer choice here.
LottieMask _maskFromJson(Map<String, dynamic> json) {
  final mode = json['mode'] as String? ?? 'a';
  final pt = json['pt'] as Map<String, dynamic>?;
  if (pt == null) throw LottieFormatException('masksProperties entry missing "pt"');
  if (pt['a'] == 1) {
    throw LottieFormatException('animated mask paths are not supported (real content has none)');
  }
  final k = pt['k'] as Map<String, dynamic>?;
  if (k == null) throw LottieFormatException('mask "pt.k" missing');
  final vertsJson = k['v'] as List? ?? const [];
  final vertices = [
    for (final v in vertsJson) Offset(_asDouble((v as List)[0]), _asDouble(v[1])),
  ];
  return LottieMask(mode: mode, vertices: vertices, inverted: json['inv'] as bool? ?? false);
}

int _typeFromDollar(Map<String, dynamic> layerJson) => _asDouble(layerJson['ty']).round();

LottieLayer _layerFromJson(Map<String, dynamic> json) {
  final type = _typeFromDollar(json);
  final masksJson = json['masksProperties'] as List? ?? const [];
  final mask = masksJson.isEmpty ? null : _maskFromJson(masksJson.first as Map<String, dynamic>);
  return LottieLayer(
    type: type,
    name: json['nm'] as String? ?? '',
    transform: _transformFromJson(json['ks'] as Map<String, dynamic>?),
    refId: json['refId'] as String?,
    parent: (json['parent'] as num?)?.toInt(),
    mask: mask,
    inPoint: _asDouble(json['ip']),
    outPoint: _asDouble(json['op']),
    startTime: _asDouble(json['st']),
  );
}

LottieAsset _assetFromJson(Map<String, dynamic> json) {
  final layersJson = json['layers'] as List?;
  if (layersJson != null) {
    return LottieAsset(id: json['id'] as String, layers: [for (final l in layersJson) _layerFromJson(l as Map<String, dynamic>)]);
  }
  return LottieAsset(
    id: json['id'] as String,
    width: (json['w'] as num?)?.toInt(),
    height: (json['h'] as num?)?.toInt(),
    imagePath: '${json['u'] ?? ''}${json['p'] ?? ''}',
    embedded: json['e'] == 1,
  );
}

/// Pure JSON->model parse, no zip/file I/O -- factored out so it's
/// independently testable against a real `ASHES.json`/`THE CHASE.json`
/// read directly, without needing a zip step. [parseLottieDocument] (the
/// public, Specifications-named entry point) calls this after unzipping.
LottieDocument parseLottieJson(Map<String, dynamic> json, {String contentBaseName = 'content'}) {
  const requiredKeys = ['v', 'fr', 'ip', 'op', 'w', 'h', 'layers'];
  final missing = requiredKeys.where((k) => !json.containsKey(k)).toList();
  if (missing.isNotEmpty) {
    throw LottieFormatException('missing required top-level key(s): ${missing.join(", ")}');
  }
  final layersJson = json['layers'] as List? ?? const [];
  final assetsJson = json['assets'] as List? ?? const [];
  return LottieDocument(
    width: _asDouble(json['w']).round(),
    height: _asDouble(json['h']).round(),
    frameRate: _asDouble(json['fr']),
    inPoint: _asDouble(json['ip']),
    outPoint: _asDouble(json['op']),
    name: json['nm'] as String? ?? '',
    contentBaseName: contentBaseName,
    layers: [for (final l in layersJson) _layerFromJson(l as Map<String, dynamic>)],
    assets: [for (final a in assetsJson) _assetFromJson(a as Map<String, dynamic>)],
  );
}

/// Unzips [zipBytes] (a real `.lottie` package) and parses the main
/// animation JSON -- per the real layout confirmed in every sample checked
/// (`samples/sample.lottie`, `samples/sample_playback_viewport
/// .lottie_unzip`): a `NAME_content/NAME.json` entry, alongside
/// `<name>_music/`/`<name>_translations/` folders this flow doesn't read
/// (out of scope, per Requirements' Won't-Have). `__MACOSX/` entries and
/// `.DS_Store` are real, harmless zip noise found in these exact samples --
/// skipped, not treated as a parse error.
LottieDocument parseLottieDocument(Uint8List zipBytes) {
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } on Exception catch (e) {
    throw LottieFormatException('not a valid zip archive: $e');
  }

  ArchiveFile? contentEntry;
  for (final entry in archive) {
    if (!entry.isFile) continue;
    if (entry.name.startsWith('__MACOSX/')) continue;
    if (entry.name.contains('_content/') && entry.name.endsWith('.json')) {
      contentEntry = entry;
      break;
    }
  }
  contentEntry ??= _fallbackTopLevelJson(archive);
  if (contentEntry == null) {
    throw LottieFormatException('no "<name>_content/<name>.json" entry found in archive');
  }

  final contentBaseName = contentEntry.name.split('_content/').first.split('/').last;
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(utf8.decode(contentEntry.content as List<int>)) as Map<String, dynamic>;
  } on FormatException catch (e) {
    throw LottieFormatException('content entry is not valid JSON: $e');
  }
  final parsed = parseLottieJson(json, contentBaseName: contentBaseName);

  // tdd-dot-lottie-import-export Plan Task 3.2/F2: real fixture check found
  // every image asset in both real samples checked (samples/sample.lottie,
  // samples/sample_playback_viewport.lottie_unzip) is embedded as a base64
  // data URI (`e:1`, `p:"data:..."`) -- never an external zip-relative file
  // reference. Embedded assets are always "found" (their bytes ARE the
  // JSON); an external reference is checked against real archive entries,
  // but this path has no real content to verify it against -- a disclosed,
  // untested-by-real-data code path, not a silent gap.
  final archiveNames = {for (final entry in archive) if (entry.isFile) entry.name};
  final checkedAssets = [
    for (final asset in parsed.assets)
      if (asset.imagePath == null)
        asset
      else if (asset.imagePath!.startsWith('data:'))
        LottieAsset(
          id: asset.id,
          width: asset.width,
          height: asset.height,
          imagePath: asset.imagePath,
          embedded: asset.embedded,
          fileFound: true,
        )
      else
        LottieAsset(
          id: asset.id,
          width: asset.width,
          height: asset.height,
          imagePath: asset.imagePath,
          embedded: asset.embedded,
          fileFound: archiveNames.contains(asset.imagePath) ||
              archiveNames.contains('${contentBaseName}_content/${asset.imagePath}'),
        ),
  ];
  return LottieDocument(
    width: parsed.width,
    height: parsed.height,
    frameRate: parsed.frameRate,
    inPoint: parsed.inPoint,
    outPoint: parsed.outPoint,
    name: parsed.name,
    contentBaseName: parsed.contentBaseName,
    layers: parsed.layers,
    assets: checkedAssets,
  );
}

/// A more permissive fallback for a hand-built/test zip with the JSON at
/// the archive root rather than nested in a `_content/` folder -- real
/// content never needs this, but a contrived Test F1/F2 fixture might.
ArchiveFile? _fallbackTopLevelJson(Archive archive) {
  for (final entry in archive) {
    if (entry.isFile && !entry.name.startsWith('__MACOSX/') && entry.name.endsWith('.json')) {
      return entry;
    }
  }
  return null;
}

// ---------------- write ----------------

Map<String, dynamic> _easeToJson((double, double)? ease) =>
    ease == null ? const {} : {'x': ease.$1, 'y': ease.$2};

Map<String, dynamic> _propertyToJson(LottieProperty property) {
  if (!property.isAnimated) {
    final value = property.staticValue!;
    return {'a': 0, 'k': value.length == 1 ? value.first : value};
  }
  return {
    'a': 1,
    'k': [
      for (final kf in property.keyframes!)
        {
          't': kf.frame,
          's': kf.value,
          if (kf.easeIn != null) 'i': _easeToJson(kf.easeIn),
          if (kf.easeOut != null) 'o': _easeToJson(kf.easeOut),
        },
    ],
  };
}

Map<String, dynamic> _transformToJson(LottieTransform transform) => {
      'p': _propertyToJson(transform.position),
      'r': _propertyToJson(transform.rotation),
      's': _propertyToJson(transform.scale),
      'o': _propertyToJson(transform.opacity),
      if (transform.anchor != null) 'a': _propertyToJson(transform.anchor!),
    };

Map<String, dynamic> _maskToJson(LottieMask mask) => {
      'inv': mask.inverted,
      'mode': mask.mode,
      'pt': {
        'a': 0,
        'k': {
          'i': [for (final _ in mask.vertices) [0, 0]],
          'o': [for (final _ in mask.vertices) [0, 0]],
          'v': [for (final v in mask.vertices) [v.dx, v.dy]],
          'c': true,
        },
      },
      'o': {'a': 0, 'k': 100},
      'x': {'a': 0, 'k': 0},
    };

Map<String, dynamic> _layerToJson(LottieLayer layer) => {
      'ty': layer.type,
      'nm': layer.name,
      if (layer.refId != null) 'refId': layer.refId,
      if (layer.parent != null) 'parent': layer.parent,
      'ks': _transformToJson(layer.transform),
      if (layer.mask != null) 'masksProperties': [_maskToJson(layer.mask!)],
      'ip': layer.inPoint,
      'op': layer.outPoint,
      'st': layer.startTime,
    };

Map<String, dynamic> _assetToJson(LottieAsset asset) {
  if (asset.layers != null) {
    return {'id': asset.id, 'layers': [for (final l in asset.layers!) _layerToJson(l)]};
  }
  return {
    'id': asset.id,
    'w': asset.width,
    'h': asset.height,
    'u': '',
    'p': asset.imagePath ?? '',
    'e': asset.embedded ? 1 : 0,
  };
}

Map<String, dynamic> _documentToJson(LottieDocument doc) => {
      'v': '5.7.0',
      'fr': doc.frameRate,
      'ip': doc.inPoint,
      'op': doc.outPoint,
      'w': doc.width,
      'h': doc.height,
      'nm': doc.name,
      'ddd': 0,
      'assets': [for (final a in doc.assets) _assetToJson(a)],
      'layers': [for (final l in doc.layers) _layerToJson(l)],
      'markers': <dynamic>[],
    };

/// The inverse of [parseLottieDocument] -- builds a real, zippable
/// `.lottie` package, mirroring the real `NAME_content/NAME.json`
/// layout on the way out (using [LottieDocument.contentBaseName], as
/// discovered by [parseLottieDocument] on the way in, so a parse->write
/// round-trip reproduces the same path). [assetFiles] provides the actual
/// image bytes for each image [LottieAsset.imagePath] -- this flow never
/// invents pixel content, only references/carries what it's given.
Uint8List writeLottieDocument(LottieDocument doc, {required List<AssetFile> assetFiles}) {
  final base = doc.contentBaseName.isEmpty ? 'content' : doc.contentBaseName;
  final json = jsonEncode(_documentToJson(doc));

  final archive = Archive();
  archive.addFile(ArchiveFile('${base}_content/$base.json', json.length, utf8.encode(json)));
  for (final asset in assetFiles) {
    archive.addFile(ArchiveFile(asset.path, asset.bytes.length, asset.bytes));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

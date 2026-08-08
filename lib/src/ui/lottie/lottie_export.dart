import 'dart:ui';

import '../../bridge/lottie_mapping.dart';
import '../anim/keyframe_interpolator.dart';
import '../models.dart';
import 'lottie_import.dart' show EasingChoice, ExportImportMode;

/// tdd-dot-lottie-import-export Plan Task 5.1-5.4: `ComicsDoc` -> real
/// `LottieDocument`. Per Requirements' own framing, this is the "easy
/// direction" -- deterministic, no user review step needed (unlike
/// import's triage screen).
///
/// **Real, disclosed scope boundary, symmetric to `commitImport`'s own
/// (Plan Task 4.1)**: this function builds a structurally correct
/// `LottieDocument` (transforms, grouping, scene sweeps, masks), but does
/// **not** embed real image pixel bytes -- `EditorLayer.images` holds tile
/// *file references* on disk, and this function's signature (`ComicsDoc`
/// only) has no access to a document's real `CoreDocument.tempFolder` to
/// read them from, the same limitation `commitImport` has in the other
/// direction. Every exported image asset gets a placeholder `imagePath`;
/// wiring real pixel bytes in is deferred to the same controller-level
/// follow-up as import's Task 6.4, not solved here.
LottieDocument buildLottieExport(
  ComicsDoc doc,
  ExportImportMode mode, {
  double? scrollSpeed,
  int? viewportWidth,
  int? viewportHeight,
  required EasingChoice easing,
}) {
  // Plan Task 4.3's own disclosure applies here too -- easing choice has no
  // observable effect yet, since .comics has one fixed interpolation
  // formula regardless.
  return mode == ExportImportMode.fullCanvas
      ? _buildFullCanvas(doc)
      : _buildPlaybackViewport(
          doc,
          scrollSpeed: scrollSpeed ?? 1.0,
          viewportWidth: viewportWidth ?? doc.preferredViewportWidth,
          viewportHeight: viewportHeight ?? doc.preferredViewportHeight,
        );
}

int _placeholderAssetCounter = 0;

LottieAsset _placeholderImageAsset() =>
    LottieAsset(id: 'image_${_placeholderAssetCounter++}', width: 1, height: 1, imagePath: 'data:image/png;base64,');

LottieTransform _identityTransform() => LottieTransform(
      position: LottieProperty.static(const [0, 0, 0]),
      rotation: LottieProperty.static(const [0]),
      scale: LottieProperty.static(const [100, 100, 100]),
      opacity: LottieProperty.static(const [100]),
    );

/// Converts one `.comics` Anim chain (already-baked absolute values, per
/// this format's own established convention) into a Lottie property.
/// Targets the primary real case -- a chain shaped like this flow's own
/// `commitImport` output (one value per `Anim`, `.end` as the keyframe
/// frame point) -- round-tripping that shape exactly; an arbitrary
/// hand-authored chain with unusual tying/ordering is not specially
/// handled beyond this.
/// Found via the real G3 round-trip test: emitting only one keyframe per
/// `Anim` (at its `.end`) silently drops `.start` -- for a real chain like
/// `[(0,0,rest),(9607,10863,moved)]` (hold at rest, then ease into
/// `moved`), that produced exactly 2 Lottie keyframes spanning the *whole*
/// `[0,10863]` range, turning the real held-then-eased shape into one
/// long linear ramp. Fixed by also emitting a keyframe at each anim's own
/// `.start` (holding the *previous* anim's value there) whenever that
/// start is later than the last keyframe already emitted -- reconstructs
/// the real held segment exactly, at the cost of one extra (functionally
/// no-op where there's no real gap) keyframe per anim.
LottieProperty _propertyFromAnims(
  List<Anim> anims,
  double scrollSpeed,
  List<double> Function(Anim) valuesOf,
) {
  if (anims.isEmpty) return LottieProperty.static(const [0, 0, 0]);
  if (anims.length == 1) return LottieProperty.static(valuesOf(anims.single));
  final keyframes = <LottieKeyframe>[
    LottieKeyframe(frame: anims.first.end / scrollSpeed, value: valuesOf(anims.first)),
  ];
  for (var i = 1; i < anims.length; i++) {
    final startFrame = anims[i].start / scrollSpeed;
    if (startFrame > keyframes.last.frame) {
      keyframes.add(LottieKeyframe(frame: startFrame, value: valuesOf(anims[i - 1])));
    }
    keyframes.add(LottieKeyframe(frame: anims[i].end / scrollSpeed, value: valuesOf(anims[i])));
  }
  return LottieProperty.animated(keyframes);
}

List<double> _translateValues(Anim a) => [a.x, a.y, 0];
List<double> _rotateValues(Anim a) => [a.angle];
// .comics's scaleX/Y are unit fractions (1 == 100%); Lottie's `s` is a
// percentage -- inverse of commitImport's own /100 conversion.
List<double> _scaleValues(Anim a) => [a.scaleX * 100, a.scaleY * 100, 100];
List<double> _alphaValues(Anim a) => [a.alpha * 100];

LottieTransform _transformFor(EditorLayer layer, double scrollSpeed) {
  final translateAnims = layer.anims.where((a) => a.type == AnimType.translate).toList();
  final rotateAnims = layer.anims.where((a) => a.type == AnimType.rotate).toList();
  final scaleAnims = layer.anims.where((a) => a.type == AnimType.scale).toList();
  final alphaAnims = layer.anims.where((a) => a.type == AnimType.alpha).toList();

  return LottieTransform(
    position: _propertyFromAnims(translateAnims, scrollSpeed, _translateValues),
    rotation: rotateAnims.isEmpty
        ? LottieProperty.static(const [0])
        : _propertyFromAnims(rotateAnims, scrollSpeed, _rotateValues),
    scale: scaleAnims.isEmpty
        ? LottieProperty.static(const [100, 100, 100])
        : _propertyFromAnims(scaleAnims, scrollSpeed, _scaleValues),
    opacity: alphaAnims.isEmpty
        ? LottieProperty.static(const [100])
        : _propertyFromAnims(alphaAnims, scrollSpeed, _alphaValues),
  );
}

/// Test C2/D3's inverse: `TextRegion.shape == "polygon"` becomes a real
/// Lottie vector mask -- the "genuine added benefit" Requirements
/// identified. `shape == "mask"` (raster) has no Lottie equivalent at
/// all -- per Open Design Question D3, this ships the recommended default
/// (skip with a disclosed limitation) rather than a lossy rasterize/
/// vectorize step nobody has signed off on.
LottieMask? _maskFor(EditorLayer layer) {
  final region = layer.textRegion;
  if (region == null) return null;
  if (region.shape == 'polygon' && region.points != null) {
    return LottieMask(mode: 'a', vertices: region.points!);
  }
  if (region.shape == 'rect' && region.rect != null) {
    final r = region.rect!;
    return LottieMask(mode: 'a', vertices: [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]);
  }
  // shape == "mask" (raster) or an unrecognized shape: no Lottie
  // equivalent -- skipped, not guessed. Disclosed via Open Design
  // Question D3, not a silent data loss (the .comics file itself is
  // untouched; only this specific export omits the mask).
  return null;
}

LottieLayer _leafLayerToLottie(EditorLayer layer, double scrollSpeed) {
  return LottieLayer(
    type: LottieLayer.typeImage,
    name: layer.name,
    refId: 'placeholder', // overwritten by the caller once the real asset id is known
    transform: _transformFor(layer, scrollSpeed),
    mask: _maskFor(layer),
  );
}

/// Playback Viewport mode's scene-member conversion -- a real, disclosed
/// correction found via the G6 round-trip test: an earlier version
/// exported each member's ALREADY-ABSOLUTE `.comics` value unchanged and
/// relied on the scene's own sweep to be added back by `commitImport` on
/// re-import, which double-counted the sweep contribution (member's own
/// value was absolute, not local, so summing it with the sweep again was
/// wrong). The correct inverse of `commitImport`'s "own + sweep" bake is
/// "own = absolute - sweep": for each required frame (the member's own
/// existing keyframe points, plus the scene's own [inFrame,outFrame]),
/// sample the member's true absolute value via the app's real
/// [KeyframeInterpolator] (not a re-implemented approximation), then
/// subtract [sweepAtFrame]'s own contribution at that same frame.
LottieLayer _sceneMemberToLottie(
  EditorLayer layer,
  double scrollSpeed,
  double inFrame,
  double outFrame,
  Offset Function(double frame) sweepAtFrame,
) {
  // The scene's own [inFrame,outFrame] boundary frames are always included,
  // even for an animated member whose own real range is a strict subset of
  // the scene's (real content confirmed: siblings genuinely move on
  // different sub-windows, e.g. `ASHES.json`'s "10_5_bg" settles into place
  // at scroll ~1048-2845 while "32_1" doesn't start until 9711, yet both
  // share one scene/precomp spanning the full [1048,33668]). Sampling via
  // `_localPositionAt` (real `KeyframeInterpolator.translateAt`) at those
  // boundary frames -- not just the member's own frames -- is required:
  // `.comics`'s own interpolator holds a member at its overall resting
  // `layer.translate` for any query outside its own defined anim window
  // (both before-first and after-last), and only by explicitly emitting
  // that same value at the scene boundary can re-import's frame-union
  // (`_bakedAnims`, which always unions a member's own keyframes with the
  // enclosing sweep's) land on the correct held value there instead of
  // Lottie-style hold-at-nearest-keyframe (which would disagree).
  final translateAnims = layer.anims.where((a) => a.type == AnimType.translate).toList();
  final frames = translateAnims.isEmpty
      ? <double>[inFrame, outFrame]
      : (<double>{
          for (final a in translateAnims) a.end / scrollSpeed,
          inFrame,
          outFrame,
        }.toList()
        ..sort());

  final positionKeyframes = [
    for (final frame in frames)
      LottieKeyframe(frame: frame, value: _localPositionAt(layer, frame, scrollSpeed, sweepAtFrame)),
  ];
  final position = positionKeyframes.length == 1
      ? LottieProperty.static(positionKeyframes.single.value)
      : LottieProperty.animated(positionKeyframes);

  final rotateAnims = layer.anims.where((a) => a.type == AnimType.rotate).toList();
  final scaleAnims = layer.anims.where((a) => a.type == AnimType.scale).toList();
  final alphaAnims = layer.anims.where((a) => a.type == AnimType.alpha).toList();

  return LottieLayer(
    type: LottieLayer.typeImage,
    name: layer.name,
    refId: 'placeholder',
    transform: LottieTransform(
      position: position,
      rotation: rotateAnims.isEmpty
          ? LottieProperty.static(const [0])
          : _propertyFromAnims(rotateAnims, scrollSpeed, _rotateValues),
      scale: scaleAnims.isEmpty
          ? LottieProperty.static(const [100, 100, 100])
          : _propertyFromAnims(scaleAnims, scrollSpeed, _scaleValues),
      opacity: alphaAnims.isEmpty
          ? LottieProperty.static(const [100])
          : _propertyFromAnims(alphaAnims, scrollSpeed, _alphaValues),
    ),
    mask: _maskFor(layer),
  );
}

List<double> _localPositionAt(
  EditorLayer layer,
  double frame,
  double scrollSpeed,
  Offset Function(double frame) sweepAtFrame,
) {
  final scrollPixel = frame * scrollSpeed;
  final absolute = KeyframeInterpolator.translateAt(layer.anims, scrollPixel, layer.translate);
  final sweep = sweepAtFrame(frame);
  return [absolute.dx - sweep.dx, absolute.dy - sweep.dy, 0];
}

LottieDocument _buildFullCanvas(ComicsDoc doc) {
  const scrollSpeed = 1.0; // identity, per Test G1 -- no ratio at all in this mode
  final grouped = <String, List<EditorLayer>>{};
  final rootLayers = <LottieLayer>[];
  final assets = <LottieAsset>[];

  for (final layer in doc.layers) {
    final groupId = layer.groupId;
    if (groupId != null) {
      grouped.putIfAbsent(groupId, () => []).add(layer);
      continue;
    }
    final asset = _placeholderImageAsset();
    assets.add(asset);
    rootLayers.add(_withRefId(_leafLayerToLottie(layer, scrollSpeed), asset.id));
  }

  // Task 5.3: groupId-sharing layers -> one shared precomp, not N
  // independent roots (Test D2, inverse of import's A3).
  for (final entry in grouped.entries) {
    final memberLayers = <LottieLayer>[];
    for (final member in entry.value) {
      final asset = _placeholderImageAsset();
      assets.add(asset);
      memberLayers.add(_withRefId(_leafLayerToLottie(member, scrollSpeed), asset.id));
    }
    assets.add(LottieAsset(id: entry.key, layers: memberLayers));
    rootLayers.add(LottieLayer(
      type: LottieLayer.typePrecomp,
      name: entry.key,
      refId: entry.key,
      transform: _identityTransform(),
    ));
  }

  return LottieDocument(
    width: doc.width,
    height: doc.height,
    frameRate: 60,
    inPoint: 0,
    outPoint: _maxEndFrame(doc.layers, scrollSpeed),
    name: 'root',
    contentBaseName: _baseNameFor(doc.name),
    layers: rootLayers,
    assets: assets,
  );
}

/// Task 5.2, DECIDED 2026-08-08 (`03-specifications.md`): partitions
/// `doc.layers` into scenes by their existing `groupId` (a layer with no
/// `groupId` becomes its own singleton scene) -- **corrected via the real
/// G6 round-trip test, twice**: (1) scene membership was originally
/// re-derived from each layer's own absolute Y position, which is wrong
/// (absolute Y and scroll-pixel position aren't the same axis once a
/// sweep is baked in) -- fixed to use the already-present `groupId`
/// signal directly. (2) each scene's scroll-pixel range was assumed to be
/// exactly one uniform `viewportHeight` -- also wrong: a real scene's
/// content can span many multiples of the viewport height of actual
/// scroll distance (confirmed: real member "32_1"'s own baked range was
/// ~9711-33668 scroll-pixels, nowhere near one 1600px band). Fixed to
/// derive each scene's real scroll-pixel range directly from the min/max
/// of its own members' existing `Anim.start`/`.end` values -- the sweep's
/// own magnitude now matches what the content actually needs, not an
/// assumed constant.
LottieDocument _buildPlaybackViewport(
  ComicsDoc doc, {
  required double scrollSpeed,
  required int viewportWidth,
  required int viewportHeight,
}) {
  final groups = <String, List<EditorLayer>>{};
  var nextSingletonId = 0;
  for (final layer in doc.layers) {
    final key = layer.groupId ?? '__singleton_${nextSingletonId++}';
    groups.putIfAbsent(key, () => []).add(layer);
  }
  final orderedKeys = groups.keys.toList()
    ..sort((a, b) {
      final ay = groups[a]!.map(_restingY).reduce((x, y) => x < y ? x : y);
      final by = groups[b]!.map(_restingY).reduce((x, y) => x < y ? x : y);
      return ay.compareTo(by);
    });

  final rootLayers = <LottieLayer>[];
  final assets = <LottieAsset>[];
  var maxOutFrame = 0.0;

  for (var sceneIndex = 0; sceneIndex < orderedKeys.length; sceneIndex++) {
    final members = groups[orderedKeys[sceneIndex]]!;
    final (scrollStart, scrollEnd) = _scrollRangeOf(members);
    final bandStartY = scrollStart;
    final bandEndY = scrollEnd > scrollStart ? scrollEnd : scrollStart + viewportHeight;
    final inFrame = bandStartY / scrollSpeed;
    final outFrame = bandEndY / scrollSpeed;
    maxOutFrame = outFrame > maxOutFrame ? outFrame : maxOutFrame;

    Offset sweepAtFrame(double frame) {
      if (outFrame == inFrame) return Offset(0, -bandStartY);
      final t = ((frame - inFrame) / (outFrame - inFrame)).clamp(0.0, 1.0);
      final y = -bandStartY + (-(bandEndY - bandStartY)) * t;
      return Offset(0, y);
    }

    final sceneMemberLayers = <LottieLayer>[];
    for (final m in members) {
      final asset = _placeholderImageAsset();
      assets.add(asset);
      sceneMemberLayers.add(_withRefId(
        _sceneMemberToLottie(m, scrollSpeed, inFrame, outFrame, sweepAtFrame),
        asset.id,
      ));
    }

    final sceneCompId = 'scene_$sceneIndex';
    assets.add(LottieAsset(id: sceneCompId, layers: sceneMemberLayers));

    rootLayers.add(LottieLayer(
      type: LottieLayer.typePrecomp,
      name: 'Scene $sceneIndex',
      refId: sceneCompId,
      inPoint: inFrame,
      outPoint: outFrame,
      startTime: inFrame,
      transform: LottieTransform(
        position: LottieProperty.animated([
          LottieKeyframe(frame: inFrame, value: [0, -bandStartY.toDouble(), 0]),
          LottieKeyframe(frame: outFrame, value: [0, -bandEndY.toDouble(), 0]),
        ]),
        rotation: LottieProperty.static(const [0]),
        scale: LottieProperty.static(const [100, 100, 100]),
        opacity: LottieProperty.static(const [100]),
      ),
    ));
  }

  return LottieDocument(
    width: viewportWidth,
    height: viewportHeight,
    frameRate: 60,
    inPoint: 0,
    outPoint: maxOutFrame,
    name: 'root',
    contentBaseName: _baseNameFor(doc.name),
    layers: rootLayers,
    assets: assets,
  );
}

double _restingY(EditorLayer layer) {
  final translateAnims = layer.anims.where((a) => a.type == AnimType.translate).toList();
  return translateAnims.isEmpty ? layer.translate.dy : translateAnims.first.y;
}

/// The real scroll-pixel range a scene's shared sweep actually spans --
/// **not** an assumed uniform `viewportHeight`-per-scene band (see
/// `_buildPlaybackViewport`'s doc comment for the real-content
/// counterexample that disproved that assumption), and **not** simply the
/// min/max across every member's own anim boundaries either (found via a
/// second real round-trip failure): a member can have real *local* motion
/// well outside the group's shared window -- e.g. `ASHES.json`'s
/// "10_5_bg" settles into place at scroll ~1048-2845 entirely on its own,
/// before the group sweep (real range 9711-33668, confirmed against the
/// scene's own root layer) starts. Using that outlier's `1048` as
/// `bandStartY` forced every OTHER member's exported position to define
/// an extra, spurious keyframe spanning the gap between the sweep's start
/// and that member's own real first frame -- and since `.comics`'s render
/// interpolator eases *between* whatever keyframes exist, that extra
/// keyframe produced a visible ramp where the original just held flat.
/// The real signal for "where does the shared sweep actually start/end"
/// is which frame the *most* members agree on -- confirmed against real
/// data: dozens of `ASHES.json` members share the exact literal chain
/// `[(9711,9711),(9711,33668)]`, i.e. 9711/33668 are by far the most
/// common boundary values, while `10_5_bg`-style outliers each contribute
/// their own one-off value that doesn't repeat. Falls back to true
/// min/max when there's no repeated value at all (e.g. very few members).
(double, double) _scrollRangeOf(List<EditorLayer> members) {
  final translateAnims = [
    for (final m in members) ...m.anims.where((a) => a.type == AnimType.translate),
  ].where((a) => a.start != a.end).toList();
  if (translateAnims.isEmpty) {
    final y = members.map(_restingY).reduce((a, b) => a < b ? a : b);
    return (y, y);
  }
  final counts = <double, int>{};
  for (final a in translateAnims) {
    counts[a.start.toDouble()] = (counts[a.start.toDouble()] ?? 0) + 1;
    counts[a.end.toDouble()] = (counts[a.end.toDouble()] ?? 0) + 1;
  }
  // Top 2 *distinct* values by how many members agree on them -- not
  // requiring equal counts, since the sweep's own true start and end
  // don't necessarily get referenced by exactly the same number of
  // members (e.g. one member's own chain might not touch the start frame
  // at all if it's active for the whole scene).
  final byFrequency = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  if (byFrequency.length >= 2 && counts[byFrequency[0]]! > 1 && counts[byFrequency[1]]! > 1) {
    final top2 = [byFrequency[0], byFrequency[1]]..sort();
    return (top2.first, top2.last);
  }
  final start = translateAnims.map((a) => a.start.toDouble()).reduce((a, b) => a < b ? a : b);
  final end = translateAnims.map((a) => a.end.toDouble()).reduce((a, b) => a > b ? a : b);
  return (start, end);
}

double _maxEndFrame(List<EditorLayer> layers, double scrollSpeed) {
  var max = 0.0;
  for (final layer in layers) {
    for (final anim in layer.anims) {
      final frame = anim.end / scrollSpeed;
      if (frame > max) max = frame;
    }
  }
  return max;
}

LottieLayer _withRefId(LottieLayer layer, String refId) => LottieLayer(
      type: layer.type,
      name: layer.name,
      refId: refId,
      parent: layer.parent,
      transform: layer.transform,
      mask: layer.mask,
      inPoint: layer.inPoint,
      outPoint: layer.outPoint,
      startTime: layer.startTime,
    );

String _baseNameFor(String docName) {
  final stem = docName.replaceAll(RegExp(r'\.(comics|puzzle)$'), '');
  return stem.isEmpty ? 'export' : stem;
}

import 'package:flutter/widgets.dart';

import '../../bridge/lottie_mapping.dart';
import '../models.dart';

/// tdd-dot-lottie-import-export Plan Task 3.1-3.3: mode detection +
/// `ImportPreview` (per-layer classification, no `.comics` mutation yet --
/// that's `commitImport`, a separate Plan Task 4.x). Grounded throughout in
/// real fixtures: `samples/sample_v2012.comics_unzip` (Full Canvas,
/// ~38:1 width:height, no sweep structure) and `samples/
/// sample_playback_viewport.lottie_unzip`'s real `ASHES.json` (Playback
/// Viewport, ~2.2:1, 2 root precomps each with a real, ~150px/sec sweep).

/// Per `03-specifications.md`, DECIDED 2026-08-08.
enum ExportImportMode { fullCanvas, playbackViewport }

/// Real sweeps move thousands of px (confirmed: ~13000/~24000 in
/// `ASHES.json`, roughly 8-15x the real viewport height); local decorative
/// wiggles are tens to low hundreds. Half the composition's own height as
/// the threshold comfortably separates the two without hardcoding a magic
/// number unrelated to the composition's own scale -- found via testing
/// that a *full* `document.height` threshold was a real boundary bug: this
/// flow's own `buildLottieExport` (Task 5.2) synthesizes a minimal,
/// exactly-one-viewport-height sweep per scene, which a strict `>` height
/// check narrowly failed to recognize on re-import, even though it's
/// unambiguously a sweep, not a local wiggle.
bool _hasSweepShape(LottieLayer layer, LottieDocument document) {
  if (layer.type != LottieLayer.typePrecomp) return false;
  final position = layer.transform.position;
  if (!position.isAnimated || position.keyframes!.length < 2) return false;
  final first = position.keyframes!.first;
  final last = position.keyframes!.last;
  final spansOwnRange =
      (first.frame - layer.inPoint).abs() < 10 && (last.frame - layer.outPoint).abs() < 10;
  if (!spansOwnRange) return false;
  final firstY = first.value.length > 1 ? first.value[1] : 0.0;
  final lastY = last.value.length > 1 ? last.value[1] : 0.0;
  return (lastY - firstY).abs() > document.height / 2;
}

/// DECIDED 2026-08-08: auto-detect-with-override, per `03-specifications.md`.
/// A composition whose `w`/`h` are phone-viewport-shaped **and** whose
/// root-level layers show the confirmed real sweep shape suggests
/// `playbackViewport`; canvas-shaped with no such sweep suggests
/// `fullCanvas`. The exact aspect-ratio threshold (4.0) is a judgment call
/// separating the two real samples' actual ratios (~38:1 vs ~2.2:1), not
/// derived from any further real data point between them -- callers
/// (Phase 6's review screen) must always let the user override this.
ExportImportMode detectMode(LottieDocument document) {
  final aspectRatio = document.width == 0 ? 0.0 : document.height / document.width;
  final looksLikeViewport = aspectRatio > 0 && aspectRatio <= 4.0;
  final hasSweepShapedRootLayer = document.layers.any((l) => _hasSweepShape(l, document));
  return (looksLikeViewport && hasSweepShapedRootLayer)
      ? ExportImportMode.playbackViewport
      : ExportImportMode.fullCanvas;
}

enum LayerPreviewStatus { clean, flagged, missingAsset }

class LayerPreview {
  LayerPreview(this.sourceLayer, this.status,
      {this.reason, this.groupId, this.groupName, this.sceneIndex});
  final LottieLayer sourceLayer;
  final LayerPreviewStatus status;
  final String? reason; // populated when flagged/missingAsset (Test A2, F2)
  final String? groupId; // shared across a precomp's resolved member layers (Test A3)
  final String? groupName; // the precomp's own `nm`, shown as "(from precomp '<name>')"
  final int? sceneIndex; // playbackViewport mode only (Test G4/G5); null in fullCanvas mode

  /// The [LayerPreview] this layer's Lottie `parent` index resolves to,
  /// within the SAME Lottie composition -- lets `commitImport` wire
  /// `EditorLayer.parentId` without re-walking [LottieDocument] a second
  /// time. A disclosed addition beyond `03-specifications.md`'s literal
  /// field list, needed to make the specified design actually
  /// implementable end-to-end. Null if this layer has no parent, or its
  /// parent index resolves to a precomp layer rather than a leaf (a real,
  /// disclosed gap -- a precomp dissolves into N flat layers with no
  /// single `EditorLayer` to parent to; not exercised by any real content
  /// found, every real root layer checked has `parent: None`).
  LayerPreview? resolvedParent;
}

enum EasingChoice { exactCubicFit, easyEaseApproximation }

/// The review screen's whole data model (Category A + B + G). [mode] is
/// chosen before the preview is built, not after -- it changes how layers
/// are classified in the first place.
class ImportPreview {
  ImportPreview(this.document, this.mode, this.layers);
  final LottieDocument document;
  final ExportImportMode mode;
  final List<LayerPreview> layers;

  /// Pixels-per-frame. Only meaningful, and only ever shown in the review
  /// screen, when [mode] == playbackViewport -- Full Canvas mode is always
  /// identity and has no such dialog at all. Auto-derived by [build] from
  /// the detected root-sweep keyframes' own position-delta/frame-delta when
  /// possible (real content authors close to one consistent speed across
  /// scenes -- confirmed: `ASHES.json`'s two real sweeps compute to 2.4916
  /// and 2.5001 px/frame, 0.34% apart); still user-editable afterward,
  /// never silently un-overridable. Null when nothing could be derived
  /// (no recognized sweep shape) -- the caller must then ask the user for
  /// a plain value instead of defaulting to something invented.
  double? scrollSpeed;

  EasingChoice easing = EasingChoice.easyEaseApproximation; // matches real-content convention,
  // applies in both modes equally

  int get cleanCount => layers.where((l) => l.status == LayerPreviewStatus.clean).length;
  int get flaggedCount => layers.length - cleanCount;

  /// Builds the preview from a parsed document -- pure, no side effects,
  /// callable independently of any UI.
  static ImportPreview build(LottieDocument document, ExportImportMode mode) {
    final assetsById = {for (final a in document.assets) a.id: a};
    final layers = mode == ExportImportMode.fullCanvas
        ? _resolveComposition(document.layers, assetsById, allowNestedPrecomp: true)
        : _resolvePlaybackViewportScenes(document, assetsById);
    final preview = ImportPreview(document, mode, layers);
    if (mode == ExportImportMode.playbackViewport) {
      preview.scrollSpeed = _deriveScrollSpeed(document);
    }
    return preview;
  }
}

LayerPreviewStatus _statusFor(LottieLayer layer, Map<String, LottieAsset> assetsById) {
  if (layer.type == LottieLayer.typeImage) {
    final asset = layer.refId == null ? null : assetsById[layer.refId];
    if (asset == null || asset.fileFound == false) return LayerPreviewStatus.missingAsset;
    return LayerPreviewStatus.clean;
  }
  return layer.isSupported ? LayerPreviewStatus.clean : LayerPreviewStatus.flagged;
}

/// Resolves one Lottie composition (either [LottieDocument.layers] itself,
/// or one precomp asset's own `layers`) into a flat [LayerPreview] list --
/// image layers become one clean/missingAsset entry each; precomp layers
/// recursively expand into their own resolved members (tagged with a
/// shared [groupId]/[groupName]); everything else is flagged. `parent`
/// indices are resolved within this composition only, per [LayerPreview
/// .resolvedParent]'s own doc comment.
List<LayerPreview> _resolveComposition(
  List<LottieLayer> composition,
  Map<String, LottieAsset> assetsById, {
  String? groupId,
  String? groupName,
  int? sceneIndex,
  required bool allowNestedPrecomp,
}) {
  final leafPreviewByIndex = <int, LayerPreview>{};
  final result = <LayerPreview>[];

  for (var i = 0; i < composition.length; i++) {
    final layer = composition[i];
    if (layer.type == LottieLayer.typePrecomp) {
      final asset = assetsById[layer.refId];
      if (asset == null || asset.layers == null) {
        result.add(LayerPreview(
          layer,
          LayerPreviewStatus.missingAsset,
          reason: 'precomp refId "${layer.refId}" not found among assets',
          groupId: groupId,
          groupName: groupName,
          sceneIndex: sceneIndex,
        ));
        continue;
      }
      if (!allowNestedPrecomp) {
        result.add(LayerPreview(
          layer,
          LayerPreviewStatus.flagged,
          reason: 'unsupported: precomp-of-precomp nesting beyond one level',
          groupId: groupId,
          groupName: groupName,
          sceneIndex: sceneIndex,
        ));
        continue;
      }
      result.addAll(_resolveComposition(
        asset.layers!,
        assetsById,
        groupId: groupId ?? asset.id,
        groupName: groupName ?? layer.name,
        sceneIndex: sceneIndex,
        allowNestedPrecomp: false,
      ));
      continue;
    }
    final status = _statusFor(layer, assetsById);
    final preview = LayerPreview(
      layer,
      status,
      reason: switch (status) {
        LayerPreviewStatus.flagged => layer.unsupportedReason,
        LayerPreviewStatus.missingAsset => 'referenced asset not found or its file is missing',
        LayerPreviewStatus.clean => null,
      },
      groupId: groupId,
      groupName: groupName,
      sceneIndex: sceneIndex,
    );
    leafPreviewByIndex[i] = preview;
    result.add(preview);
  }

  for (var i = 0; i < composition.length; i++) {
    final parentIndex = composition[i].parent;
    final preview = leafPreviewByIndex[i];
    if (preview != null && parentIndex != null) {
      preview.resolvedParent = leafPreviewByIndex[parentIndex];
    }
  }

  return result;
}

/// Playback Viewport mode: only root-level layers with the confirmed real
/// sweep shape are treated as scenes; every other root layer is flagged
/// (per the "zero scenes" edge case -- not yet precisely specified in
/// `03-specifications.md`, so flagged rather than silently imported as an
/// ordinary layer, since this mode's whole point is scene-based scroll
/// recovery).
List<LayerPreview> _resolvePlaybackViewportScenes(
  LottieDocument document,
  Map<String, LottieAsset> assetsById,
) {
  final result = <LayerPreview>[];
  var sceneIndex = 0;
  for (final layer in document.layers) {
    if (!_hasSweepShape(layer, document)) {
      result.add(LayerPreview(
        layer,
        LayerPreviewStatus.flagged,
        reason: 'not a recognized Playback Viewport scene (no root-sweep shape detected)',
      ));
      continue;
    }
    final asset = assetsById[layer.refId];
    if (asset == null || asset.layers == null) {
      result.add(LayerPreview(
        layer,
        LayerPreviewStatus.missingAsset,
        reason: 'scene precomp refId "${layer.refId}" not found among assets',
      ));
      continue;
    }
    result.addAll(_resolveComposition(
      asset.layers!,
      assetsById,
      groupId: asset.id,
      groupName: layer.name,
      sceneIndex: sceneIndex,
      allowNestedPrecomp: false,
    ));
    sceneIndex++;
  }
  return result;
}

/// DECIDED 2026-08-08, grounded in exact computation on real data:
/// averages the per-frame speed of every detected sweep -- real content's
/// scenes agree within 0.34% of each other (`ASHES.json`: 2.4916 and
/// 2.5001 px/frame), so an average is a faithful single value, not a lossy
/// compromise. Returns null when nothing could be derived.
double? _deriveScrollSpeed(LottieDocument document) {
  final speeds = <double>[];
  for (final layer in document.layers) {
    if (!_hasSweepShape(layer, document)) continue;
    final position = layer.transform.position;
    final first = position.keyframes!.first;
    final last = position.keyframes!.last;
    final dFrames = last.frame - first.frame;
    if (dFrames <= 0) continue;
    final firstY = first.value.length > 1 ? first.value[1] : 0.0;
    final lastY = last.value.length > 1 ? last.value[1] : 0.0;
    speeds.add((lastY - firstY).abs() / dFrames);
  }
  if (speeds.isEmpty) return null;
  return speeds.reduce((a, b) => a + b) / speeds.length;
}

// ---------------- commitImport (Plan Task 4.1/4.2/4.4) ----------------

/// Applies [preview]'s current choices, mutating [doc]. No-op-safe to
/// never call (cancel just discards the `ImportPreview` object -- no
/// mutation has happened yet by construction).
///
/// **Real, disclosed scope boundary found while implementing this**: this
/// function creates real `EditorLayer`s with correct `Anim`/`groupId`/
/// `parentId`/`textRegion` data, but does **not** write real image pixel
/// files -- `EditorLayer.images` keeps the constructor's own placeholder
/// (matching the layer's name), not the layer's real artwork. Real
/// pixel-writing (`lib/src/io/tile_writer.dart`'s `writeTiles`) needs a
/// document's real `CoreDocument.tempFolder`, which this function's
/// Specifications-defined signature (`ImportPreview`, `ComicsDoc` only)
/// has no access to -- that has to happen at the `EditorController` level
/// (Phase 6), which does have a real tempFolder once a document is open.
/// Each clean [LayerPreview.sourceLayer]'s `refId` still correlates to a
/// real [LottieAsset] in `preview.document.assets`, so that later step can
/// find the source bytes; flagged here, not silently skipped.
void commitImport(ImportPreview preview, ComicsDoc doc) {
  // Plan Task 4.3 (EasingChoice): deliberately not consumed below, per Test
  // B3's own finding -- `.comics` has exactly one fixed cubic ease-out
  // formula (KeyframeInterpolator), so "exactCubicFit" and
  // "easyEaseApproximation" currently produce identical output regardless
  // of which is chosen (both converge to the same, only-available formula).
  // `preview.easing` stays a real, wired-through choice for the review
  // screen to show (Phase 6), not a silently-ignored field -- it just has
  // no observable effect yet, which is disclosed here rather than hidden
  // behind an unused-field warning.

  // Full Canvas mode: identity, no ratio at all (Test G1/G2). Playback
  // Viewport mode: the derived/user-supplied px/frame speed converts
  // Lottie frame numbers into .comics scroll-pixels.
  final scrollSpeed =
      preview.mode == ExportImportMode.playbackViewport ? (preview.scrollSpeed ?? 1.0) : 1.0;

  final createdLayers = <LayerPreview, EditorLayer>{};
  for (final layerPreview in preview.layers) {
    if (layerPreview.status != LayerPreviewStatus.clean) continue;
    final sweep = _sweepFor(preview.document, layerPreview.groupId);
    final editorLayer = _buildEditorLayer(layerPreview, sweep, scrollSpeed);
    createdLayers[layerPreview] = editorLayer;
    doc.layers.add(editorLayer);
  }

  // Second pass: every clean layer now has a real EditorLayer.id, so
  // Layer.ParentId can be wired without re-walking LottieDocument again.
  for (final entry in createdLayers.entries) {
    final parentPreview = entry.key.resolvedParent;
    final parentLayer = parentPreview == null ? null : createdLayers[parentPreview];
    if (parentLayer != null) entry.value.parentId = parentLayer.id;
  }
}

/// The enclosing precomp/scene's own root [LottieLayer] for [groupId] (its
/// `refId` matches the precomp asset's `id`, which is what [groupId]
/// itself is set to by `_resolveComposition`/`_resolvePlaybackViewportScenes`)
/// -- its own transform is what gets baked into each member's keyframes
/// below. Null for a top-level (non-grouped) layer.
LottieLayer? _sweepFor(LottieDocument document, String? groupId) {
  if (groupId == null) return null;
  for (final layer in document.layers) {
    if (layer.type == LottieLayer.typePrecomp && layer.refId == groupId) return layer;
  }
  return null;
}

EditorLayer _buildEditorLayer(LayerPreview layerPreview, LottieLayer? sweep, double scrollSpeed) {
  final source = layerPreview.sourceLayer;
  final editorLayer = EditorLayer(source.name.isEmpty ? 'layer' : source.name)
    ..groupId = layerPreview.groupId;

  final mask = source.mask;
  if (mask != null) {
    // Test C2: Lottie masks are always vector paths, never raster -- this
    // import path should never produce TextRegion.shape == "mask" (that's
    // exclusively comics-ai-baloons' own raster path).
    editorLayer.textRegion = TextRegion(
      shape: 'polygon',
      points: [for (final v in mask.vertices) Offset(v.dx, v.dy)],
    );
  }

  editorLayer.anims.clear(); // replaced below with real, baked keyframes

  final transform = source.transform;
  final sweepTransform = sweep?.transform;

  final translateAnims = _bakedAnims(
    AnimType.translate,
    own: transform.position,
    sweep: sweepTransform?.position,
    scrollSpeed: scrollSpeed,
    combine: _sum, // position: two independent motions add (own local + enclosing sweep)
    componentX: 0,
    componentY: 1,
  );
  editorLayer.anims.addAll(translateAnims);
  if (translateAnims.isNotEmpty) {
    editorLayer.translate = Offset(translateAnims.last.x, translateAnims.last.y);
  }

  // Rotation/scale/opacity: real content never animates these on the
  // enclosing precomp/scene itself (confirmed: THE checked real sweeps'
  // own r/s/o are all static) -- so no `sweep` term is passed for them;
  // only the member's own values, frame->scroll-pixel scaled.
  // Rotate/scale/alpha: only emit an Anim when the source is actually
  // animated or its static value differs from that property's neutral
  // resting default (angle=0, scale=100%, opacity=100) -- real hand-
  // authored .comics content doesn't carry a no-op Anim for every
  // property on every layer, and neither should an import. Every
  // EditorLayer's constructor already seeds a resting Translate anim, so
  // translate alone always gets at least one entry regardless.
  if (transform.rotation.isAnimated || _asDouble(transform.rotation.staticValue!, 0) != 0) {
    editorLayer.anims.addAll(_bakedAnims(
      AnimType.rotate,
      own: transform.rotation,
      scrollSpeed: scrollSpeed,
      combine: _sum,
      componentX: 0,
      componentY: 0,
    ));
  }
  if (transform.scale.isAnimated ||
      _asDouble(transform.scale.staticValue!, 0) != 100 ||
      _asDouble(transform.scale.staticValue!, 0, index: 1) != 100) {
    editorLayer.anims.addAll(_bakedAnims(
      AnimType.scale,
      own: transform.scale,
      scrollSpeed: scrollSpeed,
      combine: _sum,
      componentX: 0,
      componentY: 1,
    ));
  }
  if (transform.opacity.isAnimated || _asDouble(transform.opacity.staticValue!, 0) != 100) {
    editorLayer.anims.addAll(_bakedAnims(
      AnimType.alpha,
      own: transform.opacity,
      scrollSpeed: scrollSpeed,
      combine: _sum,
      componentX: 0,
      componentY: 0,
    ));
  }

  if (editorLayer.anims.isEmpty) {
    editorLayer.anims.add(Anim(AnimType.translate)..y = editorLayer.translate.dy);
  }

  return editorLayer;
}

double _sum(double a, double b) => a + b;

double _asDouble(List<double> values, double fallback, {int index = 0}) =>
    index < values.length ? values[index] : fallback;

/// Converts one property (optionally with an enclosing [sweep] of the
/// same property, e.g. a scene's own sweeping position) into a chain of
/// `.comics` [Anim] segments. **Real, disclosed simplification**:
/// sampling a curve at a frame point that isn't one of its own real
/// keyframes uses linear interpolation, not Lottie's own bezier ease --
/// exact for every real case found (a static member value contributes a
/// true constant; the enclosing sweep is the only animated curve in every
/// real file checked, and its own real keyframes are used directly,
/// un-resampled, whenever the member itself is static). Only diverges
/// (by a small, disclosed amount) when BOTH the member and its enclosing
/// sweep are independently animated with different frame points -- a
/// real but less common case (confirmed present as small local wiggles
/// alongside the big sweep in `THE BROKEN TUSK`-style content).
List<Anim> _bakedAnims(
  AnimType type, {
  required LottieProperty own,
  LottieProperty? sweep,
  required double scrollSpeed,
  required double Function(double, double) combine,
  required int componentX,
  required int componentY,
}) {
  // A static `own` property contributes no real frame of its own -- frame
  // 0 was an arbitrary placeholder (any frame samples the same constant
  // value). Found via the real G6 round-trip test to be actively wrong
  // when an enclosing [sweep] is animated: unioning in frame 0 forced a
  // spurious extra keyframe at scroll-pixel 0 even for scenes whose real
  // sweep starts well after 0 (e.g. `ASHES.json`'s second scene starts at
  // scroll 9711, not 0), corrupting the exported/re-imported chain's
  // shape. Kept as `[0]` when there's no animated sweep to defer to --
  // every already-shipped standalone/static-layer case still needs some
  // frame to seed a single sample from, and 0 is as good as any there.
  final ownFrames = own.isAnimated
      ? [for (final k in own.keyframes!) k.frame]
      : (sweep != null && sweep.isAnimated ? const <double>[] : const <double>[0]);
  final sweepFrames =
      sweep != null && sweep.isAnimated ? [for (final k in sweep.keyframes!) k.frame] : const <double>[];
  final frames = <double>{...ownFrames, ...sweepFrames}.toList()..sort();
  if (frames.isEmpty) return const [];

  final samples = [
    for (final frame in frames)
      (
        frame: frame,
        x: combine(
          _sampleAt(own, frame, componentX),
          sweep == null ? 0 : _sampleAt(sweep, frame, componentX),
        ),
        y: combine(
          _sampleAt(own, frame, componentY),
          sweep == null ? 0 : _sampleAt(sweep, frame, componentY),
        ),
      ),
  ];

  if (samples.length == 1) {
    final only = samples.single;
    final scrollFrame = (only.frame * scrollSpeed).round();
    return [_animFor(type, scrollFrame, scrollFrame, only.x, only.y)];
  }

  final anims = <Anim>[];
  final seedFrame = (samples.first.frame * scrollSpeed).round();
  anims.add(_animFor(type, seedFrame, seedFrame, samples.first.x, samples.first.y));
  for (var i = 1; i < samples.length; i++) {
    final start = (samples[i - 1].frame * scrollSpeed).round();
    final end = (samples[i].frame * scrollSpeed).round();
    anims.add(_animFor(type, start, end, samples[i].x, samples[i].y));
  }
  return anims;
}

double _sampleAt(LottieProperty property, double frame, int componentIndex) {
  double at(List<double> v) => componentIndex < v.length ? v[componentIndex] : 0;
  if (!property.isAnimated) return at(property.staticValue!);
  final keyframes = property.keyframes!;
  if (frame <= keyframes.first.frame) return at(keyframes.first.value);
  if (frame >= keyframes.last.frame) return at(keyframes.last.value);
  for (var i = 0; i < keyframes.length - 1; i++) {
    final a = keyframes[i], b = keyframes[i + 1];
    if (frame >= a.frame && frame <= b.frame) {
      final t = (frame - a.frame) / (b.frame - a.frame);
      return at(a.value) + (at(b.value) - at(a.value)) * t;
    }
  }
  return at(keyframes.last.value);
}

Anim _animFor(AnimType type, int start, int end, double x, double y) {
  final anim = Anim(type, start: start, end: end);
  switch (type) {
    case AnimType.translate:
      anim.x = x;
      anim.y = y;
    case AnimType.rotate:
      anim.angle = x;
    case AnimType.scale:
      // Lottie's `s` is a percentage (100 == 100%); .comics's scaleX/Y is a
      // unit fraction (1 == 100%, matching Anim's own default) -- confirmed
      // real content uses 100/100/100 for "no scale change" throughout.
      anim.scaleX = x / 100;
      anim.scaleY = y / 100;
    case AnimType.alpha:
      // Lottie's `o` is 0-100; .comics's alpha is 0-1 (matching Anim's own
      // default of 1 == fully opaque).
      anim.alpha = x / 100;
    case AnimType.sound:
      break;
  }
  return anim;
}

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../i18n/language_registry.dart';

const _uuid = Uuid();

/// Domain model — mirrors the WPF Comics.Editor models 1:1
/// (Layer, Sound, Anim + AnimTypes, Cultures) with no invented functionality.

enum DocType { comics, puzzle }

/// tdd-dot-comics-format Plan Task 2.1: content-scroll axis, independent of
/// device [PreferredOrientation] -- never coupled or inferred from it
/// (03-specifications.md). Default `vertical` matches every document ever
/// produced (2012 through today).
enum ScrollType { vertical, horizontal }

/// tdd-dot-comics-format Plan Task 2.1: device screen orientation the
/// document prefers -- independent of [ScrollType]. Default `portrait`
/// matches every existing file's implicit, only-ever-exercised behavior.
enum PreferredOrientation { portrait, landscape, auto }

/// vdd-comics-editor-uiux-lettering, Task 5.1: view-only UI state (not
/// persisted -- like `EditorController.lang`, this lives entirely on the
/// controller). `edit` is today's existing workspace; `lettering` swaps the
/// left+right panes for the balloon rail + balloon editor (Phase 5).
/// vdd-comics-editor-ai-uiux: `cutting` is the third mode, added alongside `edit`/`lettering`.
/// Functional on desktop only (03-specifications.md/`02-visual.md`) -- the mode switch itself is
/// disabled on mobile (`top_bar.dart`), so `EditorController.mode` should never actually become
/// `cutting` there, but the enum value isn't platform-gated at this layer.
enum EditorMode { edit, lettering, cutting }

/// Review is orthogonal to the existing editing modes and never persisted.
enum EditorWorkspace { editor, viewer }

enum PropertiesTab { selection, document, general }

extension EditorModeLabel on EditorMode {
  String get label => switch (this) {
    EditorMode.edit => 'Edit',
    EditorMode.lettering => 'Lettering',
    EditorMode.cutting => 'Cutting',
  };
}

const kEditorModes = EditorMode.values;

enum Lang { en, ru, hi }

extension LangLabel on Lang {
  String get label => switch (this) {
    Lang.en => 'En',
    Lang.ru => 'Ru',
    Lang.hi => 'Hi',
  };
}

const kLangs = Lang.values;

/// AnimTypes { Translate, Rotate, Scale, Alpha, Sound }
enum AnimType { translate, rotate, scale, alpha, sound }

extension AnimTypeLabel on AnimType {
  String get label => switch (this) {
    AnimType.translate => 'Translate',
    AnimType.rotate => 'Rotate',
    AnimType.scale => 'Scale',
    AnimType.alpha => 'Alpha',
    AnimType.sound => 'Sound',
  };
}

/// tdd-dot-comics-format Plan Task 5.1/5.2: which dimension drives an
/// [Anim]'s `start`/`end` -- scroll position (today's only-ever-exercised
/// behavior, `start`/`end` are scroll-pixels/frames) or wall-clock time
/// (`start`/`end` are milliseconds). Default `scroll`, full backward
/// compat. Resolved per-`Anim`, not per-layer or per-document, since the
/// motivating case (a swinging leg animating while scroll is stationary)
/// needs some anims on a layer to stay scroll-driven while others are
/// time-driven.
enum AnimBasis { scroll, time }

/// One keyframed animation. Every anim shares Start/End (frames along the
/// scroll/timeline, or milliseconds if [basis] is `time`); type-specific
/// fields carry the rest.
class Anim {
  // vdd-comics-editor-vertical-scroll, Task 1.1: matches legacy's C# int
  // default (0) for both fields -- see models_mapping.dart's _animFromJson/
  // _animToJson for why this must stay in sync with the JSON round-trip
  // defaults. Callers that author a real keyframe range (addAnim/addSound)
  // always pass an explicit `end`, so this default only matters for
  // EditorLayer's auto-seeded resting anim.
  Anim(this.type, {this.start = 0, this.end = 0});
  AnimType type;
  int start;
  int end;

  /// tdd-dot-comics-format Plan Task 5.2. Default `scroll` -- every anim in
  /// every existing document is implicitly scroll-driven, so this must
  /// default to matching that, not `time`.
  AnimBasis basis = AnimBasis.scroll;

  /// Only meaningful when [basis] is `time`. Per Task 5.1's resolution:
  /// loops by default -- a swinging leg that stops after one swing isn't
  /// the motivating case Requirements described.
  bool loop = true;

  // translate
  double x = 0, y = 0;
  // rotate / scale pivot
  double pivotX = 0, pivotY = 0;
  double angle = 0;
  double scaleX = 1, scaleY = 1;
  // alpha
  double alpha = 1;

  String get title => type.label;

  Anim clone() => Anim(type, start: start, end: end)
    ..x = x
    ..y = y
    ..pivotX = pivotX
    ..pivotY = pivotY
    ..angle = angle
    ..scaleX = scaleX
    ..scaleY = scaleY
    ..alpha = alpha
    ..basis = basis
    ..loop = loop;
}

/// tdd-dot-comics-format Plan Task 4.1, per `03-specifications.md`'s Masks &
/// Solid Colors section: a general compositing clip on a layer's own
/// content -- deliberately separate from `TextRegion` ("where does
/// lettering go" is a different question from "what shape is my own
/// content clipped to"), even though it reuses the same shape vocabulary.
/// `shape` is an open string like [EditorLayer.kind]/[EditorLayer.style],
/// not a Dart enum, for the same JSON-flexibility reason. Only `"rect"` is
/// exercised by any real content found so far (all 6 real masks in `THE
/// CHASE` are static rectangles) -- `rect` is the only field this
/// constructor requires non-null; `points`/`maskFile` exist for
/// `"polygon"`/`"mask"` but are additive, unused by anything yet.
class LayerMask {
  LayerMask.rect(Rect value) : shape = 'rect', rect = value, points = null, maskFile = null;
  LayerMask({required this.shape, this.rect, this.points, this.maskFile});

  final String shape; // "rect" | "polygon" | "mask"
  final Rect? rect;
  final List<Offset>? points;
  final String? maskFile;

  LayerMask clone() =>
      LayerMask(shape: shape, rect: rect, points: points == null ? null : List.of(points!), maskFile: maskFile);
}

/// tdd-dot-lottie-import-export Plan Task 1.3, per `03-specifications.md`'s
/// `TextRegion` interface: same shape vocabulary as [LayerMask]
/// (rect/polygon/mask), reused for convenience -- the two concepts are not
/// the same thing ("where lettering goes" vs. "what this layer's own
/// content is clipped to"). `isHandLettered` distinguishes hand-drawn
/// lettering artwork from rendered font text; its exact relationship to
/// `EditorLayer.style == "hand_lettered"` is a deferred Requirements
/// question, not resolved by this class alone.
class TextRegion {
  TextRegion({required this.shape, this.rect, this.points, this.maskFile, this.isHandLettered});

  final String shape; // "rect" | "polygon" | "mask"
  final Rect? rect;
  final List<Offset>? points;
  final String? maskFile;
  final bool? isHandLettered;

  TextRegion clone() => TextRegion(
        shape: shape,
        rect: rect,
        points: points == null ? null : List.of(points!),
        maskFile: maskFile,
        isHandLettered: isHandLettered,
      );
}

/// A localized artwork slot — one per culture (En/Ru/Hi).
class LayerImage {
  LayerImage({this.file = '', this.popup = ''});
  String file;
  String popup;

  LayerImage clone() => LayerImage(file: file, popup: popup);
}

class EditorLayer {
  /// [id] lets [comicsFromCore] restore a persisted identity on read, and
  /// [clone] preserve one across undo/redo snapshots (see [clone]'s own
  /// doc comment for why identity must survive there). Every other caller
  /// omits it and gets a fresh one.
  EditorLayer(this.name, {Offset? at, String? id})
      : translate = at ?? Offset.zero,
        id = id ?? _uuid.v4() {
    for (var i = 0; i < kLangs.length; i++) {
      images.add(LayerImage(file: i == 0 ? name : ''));
    }
    // default anim, like Layer.Create in the original
    anims.add(Anim(AnimType.translate)..y = translate.dy);
  }

  /// Stable identity, a prerequisite for [parentId] and any other
  /// cross-layer reference. Never reassigned after construction.
  final String id;

  String name;
  bool visible = true;
  bool preview = false;
  final List<LayerImage> images = [];
  final List<Anim> anims = [];

  // live transform used by the canvas
  Offset translate;
  double size = 0.5; // fraction of page width, for the placeholder swatch
  Color swatch = const Color(0xFF57422D);

  /// tdd-dot-comics-format Plan Task 4.1, per `03-specifications.md`'s
  /// Masks & Solid Colors section: hex string (e.g. "#ffffff"), mirrors
  /// Lottie's own `sc` field. When set, takes precedence over [images] for
  /// rendering -- [images] is never cleared, so switching back from solid
  /// to image content loses nothing (the resolved precedence question,
  /// per this plan's own recommendation).
  String? solidColor;

  /// tdd-dot-comics-format Plan Task 4.1: clips this layer's own rendered
  /// content (from [images] or [solidColor]) to a shape. Null = today's
  /// exact behavior, full unclipped content.
  LayerMask? mask;

  /// vdd-comics-editor-uiux-lettering: coarse layer classification, mirrors
  /// Layer.Kind in the core (open string, e.g. "balloon"/"caption"; null =
  /// today's untyped/generic layer). Kept nullable, not defaulted to '',
  /// so "unset" round-trips as absent in JSON rather than an empty string.
  String? kind;

  /// Balloon-specific refinement of [kind] (e.g. "speech"/"hand_lettered").
  /// Mirrors Layer.Style; meaningless when kind != "balloon".
  String? style;

  /// tdd-dot-comics-format Plan Task 3.1: references another layer's [id]
  /// for hierarchical, editor-side live-relative positioning (distinct from
  /// the flat, symmetric `groupId` mechanism). Null = today's exact
  /// behavior, an independent top-level layer. Cycle prevention is enforced
  /// by the controller when setting this, not here.
  String? parentId;

  /// Marker [kind] value for a non-content, organizational-only layer (e.g.
  /// a named anchor for a character rig) -- has no [images], exists purely
  /// to be a [parentId] target or to organize.
  static const String organizationalKind = 'organizational';

  /// tdd-dot-lottie-import-export Plan Task 1.1: a flat, symmetric "these
  /// layers belong together" tag -- distinct from [parentId]'s hierarchy.
  /// Used for Lottie precomp-flattening on import (`03-specifications.md`'s
  /// Traceability Matrix, A3/D2) and `vdd-comics-editor-systematization-
  /// uiux`'s own Layer Grouping design. Whether this ends up subsumed by
  /// `parentId` for the precomp case specifically is a still-open question
  /// (per that flow's Specifications) -- kept as its own field for now.
  String? groupId;

  /// tdd-dot-lottie-import-export Plan Task 1.3: where within this layer's
  /// own image the lettering sits -- annotation only, never changes how the
  /// layer's (already fully rendered) image displays. Null = today's exact
  /// behavior for every existing layer. Two Requirements-level questions
  /// remain genuinely deferred, not resolved by this field's shape alone:
  /// (1) the relationship between [TextRegion.isHandLettered] and this
  /// layer's own [style] == "hand_lettered" value; (2) whether the
  /// region's coordinates are layer-local (implemented here, per
  /// Specifications' stated leaning) or absolute canvas coordinates.
  TextRegion? textRegion;

  /// Per-language balloon text, keyed by ISO language code. Mirrors
  /// Layer.Translations; independent of [images] — a language can have text
  /// here with no rendered artwork yet.
  final Map<String, String> translations = {};

  /// vdd-comics-editor-uiux-lettering, Task 1.2: resolves [langCode] to its
  /// [LanguageRegistry] slot index and returns that [LayerImage], extending
  /// [images] with empty placeholders as needed. Pure Dart, additive-only --
  /// en/ru/hi always land at their existing Cultures-aligned indices 0/1/2;
  /// anything else appends at the registry's fixed, append-only position.
  /// Calling this twice for the same code returns the same slot, never a
  /// duplicate.
  LayerImage imageSlotFor(String langCode, LanguageRegistry registry) {
    final index = registry.indexFor(langCode);
    if (index == null) {
      throw ArgumentError.value(langCode, 'langCode', 'Unknown language code');
    }
    while (images.length <= index) {
      images.add(LayerImage());
    }
    return images[index];
  }

  /// Deep copy — for undo/redo snapshots (see [ComicsDoc.clone]). Preserves
  /// [id] deliberately: [ComicsDoc.clone] is the only real caller
  /// (`edit_history.dart`/`controller.dart`'s undo/redo), and a snapshot
  /// must represent the *same* layers, not new ones -- a stale [parentId]
  /// reference after undo would otherwise silently break. The constructor
  /// auto-seeds default `images`/`anims`, so those are cleared and replaced
  /// with real deep copies.
  EditorLayer clone() {
    final copy = EditorLayer(name, at: translate, id: id)
      ..visible = visible
      ..preview = preview
      ..size = size
      ..swatch = swatch
      ..kind = kind
      ..style = style
      ..parentId = parentId
      ..solidColor = solidColor
      ..mask = mask?.clone()
      ..groupId = groupId
      ..textRegion = textRegion?.clone();
    copy.images.clear();
    copy.images.addAll(images.map((i) => i.clone()));
    copy.anims.clear();
    copy.anims.addAll(anims.map((a) => a.clone()));
    copy.translations.addAll(translations);
    return copy;
  }
}

class EditorSound {
  EditorSound(this.file);
  String file;
  final List<Anim> anims = [];

  EditorSound clone() {
    final copy = EditorSound(file);
    copy.anims.addAll(anims.map((a) => a.clone()));
    return copy;
  }
}

class ComicsDoc {
  ComicsDoc({
    required this.name,
    required this.type,
    this.width = 1080,
    this.height = 1920,
  });

  String name;
  DocType type;
  int width;
  int height;
  final List<EditorLayer> layers = [];
  final List<EditorSound> sounds = [];
  double scale = 1; // puzzle zoom (0.125 .. 1 in the original)

  ScrollType scrollType = ScrollType.vertical;
  PreferredOrientation preferredOrientation = PreferredOrientation.portrait;

  /// tdd-dot-comics-format Plan (2026-08-08 addition), implemented here by
  /// tdd-dot-lottie-import-export Plan Task 1.5 -- this flow is the first
  /// real consumer (Playback Viewport mode's default viewport size and
  /// scene-boundary convention for export). Independent of [scrollType]/
  /// [preferredOrientation], same as those two are independent of each
  /// other -- scale/extent of the viewing window, not direction. Default
  /// 720x1600 matches the real value found in `samples/
  /// sample_playback_viewport.lottie_unzip` (checked byte-level).
  int preferredViewportWidth = 720;
  int preferredViewportHeight = 1600;

  /// Deep copy — used by [EditHistory] to snapshot document state for
  /// undo/redo. Direct clone rather than a JSON round-trip through
  /// comicsToCore/comicsFromCore: newDoc()/openRecent() create a [ComicsDoc]
  /// with no backing [CoreDocument] (coreDoc stays null), so a snapshot
  /// strategy must work without one.
  ComicsDoc clone() {
    final copy = ComicsDoc(name: name, type: type, width: width, height: height)
      ..scale = scale
      ..scrollType = scrollType
      ..preferredOrientation = preferredOrientation
      ..preferredViewportWidth = preferredViewportWidth
      ..preferredViewportHeight = preferredViewportHeight;
    copy.layers.addAll(layers.map((l) => l.clone()));
    copy.sounds.addAll(sounds.map((s) => s.clone()));
    return copy;
  }
}

/// A file the Open dialog can list.
class RecentFile {
  const RecentFile(this.name, this.type, this.meta);
  final String name;
  final DocType type;
  final String meta;
}

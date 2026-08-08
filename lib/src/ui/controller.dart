import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:flutter_comics_viewer/flutter_comics_viewer.dart' as viewer;

// v2.9 обвязка: ядро (процесс на десктопе / NativeAOT+FFI на мобильных).
import '../ai/balloon_ai_client.dart';
// Aliased: balloon_ai_client.dart and cutting_client.dart both define RoutingDecided/Progress/
// Success/Failure as distinct sealed-event types for their respective clients -- same names by
// deliberate design symmetry (03-specifications.md mirrors BalloonAiClient's shape), so only one
// of the two can be imported unqualified here.
import '../ai/cutting_client.dart' as cutting;
import '../ai/multimodal_paths.dart';
import '../ai/stub_balloon_ai_client.dart';
import '../ai/stub_cutting_client.dart';
import '../bridge/comics_core.dart';
import '../bridge/documents.dart';
import '../bridge/models_mapping.dart';
import '../i18n/language_registry.dart';
import '../io/tile_writer.dart';
import 'audio/sound_player.dart';
import 'device_profile.dart';
import 'edit_history.dart';
import 'editor_mode.dart';

/// Which element type is selected in the right-hand Properties pane.
enum SelKind { none, layer, sound }

/// vdd-comics-editor-ai-uiux, Task 3.1: one region's review state within a [CuttingSession].
/// Never serialized -- once accepted, a region *becomes* an ordinary [EditorLayer]
/// (03-specifications.md's Data Models: "no schema changes"), indistinguishable from any other.
enum RegionStatus { pending, accepted, rejected }

class PendingRegion {
  PendingRegion({required this.region, this.status = RegionStatus.pending});
  cutting.DetectedRegion region;
  RegionStatus status;
}

/// vdd-comics-editor-ai-uiux, Task 3.1: transient Cutting-mode state -- the in-progress or
/// completed result of one `triggerCutting` call. Holds the source image bytes/layer plus every
/// proposed region's live review state. Never part of `ComicsDoc`/`data.json`.
class CuttingSession {
  CuttingSession({
    required this.sourceImageBytes,
    required this.sourceLayerIndex,
    this.sourceFileRef = '',
    this.sourceWidth = 0,
    this.sourceHeight = 0,
  });

  final Uint8List sourceImageBytes;
  final int sourceLayerIndex;

  /// vdd-comics-editor-ai-uiux: a fingerprint of the source layer's artwork -- its tile-template
  /// filename and tracked pixel dimensions (`imageDimensions`, an in-memory raw JSON read, not a
  /// disk stitch). [EditorController.refreshCuttingStaleness] compares this against the layer's
  /// *current* state to detect the "source image changed after regions were generated" edge case
  /// from Requirements. A disclosed simplification: this catches the layer being
  /// replaced/removed/resized, not a same-size in-place pixel change to the same tile filename --
  /// full byte-for-byte comparison would need a disk re-stitch on every check, which this trades
  /// off against for a cheap, in-memory-only check.
  ///
  /// Not `final`: [EditorController.dismissCuttingStale] re-baselines these to the layer's
  /// *current* state when the corrector dismisses the warning, so the very next staleness check
  /// doesn't immediately re-flag the same already-acknowledged change.
  String sourceFileRef;
  int sourceWidth;
  int sourceHeight;
  bool stale = false;

  bool onDevice = true;
  String? routingReason;
  String?
  stage; // "loading_model" | "segmenting" | "extracting_regions", null once terminal
  List<PendingRegion> regions = [];
  String? failureReason;
  bool failureRetryable = false;

  /// Set true on a terminal Success or Failure event. Not inferred from `regions.isEmpty`, since
  /// a real Success with zero detected regions is a valid (if unusual) outcome, not "still
  /// running" -- an earlier draft of this class got that inference wrong.
  bool completed = false;

  bool get isRunning => !completed;
  bool get hasFailed => failureReason != null;
}

/// Single source of truth. Every mutation calls notifyListeners();
/// widgets rebuild through EditorScope / ListenableBuilder.
class EditorController extends ChangeNotifier {
  EditorController() {
    // vdd-comics-editor-vertical-scroll, Task 4.3: drives sound gating on
    // every pan-driven currentTime change, mirroring ComicsViewModel.Scroll.
    canvasViewport.addListener(_onSoundTick);
  }

  // ---------- Anim.basis == time (tdd-dot-comics-format Plan Task 5.4) ----------
  //
  // A live-ticking `wallClock` (Timer-driven, feeding KeyframeInterpolator's
  // new wallClockMs parameter so a time-basis anim animates without user
  // interaction) was attempted here and reverted: a periodic Timer living
  // for EditorController's lifetime violates flutter_test's strict
  // no-pending-timer-after-dispose invariant, and broke ~78 unrelated tests
  // across the suite that construct a controller without a matching
  // teardown path this change assumed. KeyframeInterpolator's basis-aware
  // composition (below) is real and tested via a directly-injected
  // wallClockMs value; wiring a live clock into the canvas for real remains
  // a genuine, disclosed gap -- it needs a lifecycle-safe source (e.g. a
  // widget-scoped AnimationController with real vsync, started/stopped by
  // whichever widget actually renders a time-basis anim) that this task
  // didn't design.

  ComicsDoc? doc;
  Lang lang = Lang.en;
  bool muted = false;
  EditorWorkspace workspace = EditorWorkspace.editor;
  PropertiesTab propertiesTab = PropertiesTab.selection;
  DeviceProfile targetDeviceProfile = DeviceProfile.iPad;

  final viewer.ComicsViewerController viewerController =
      viewer.ComicsViewerController();
  viewer.ComicsViewerSource? viewerSource;
  int _previewRevision = 0;
  Directory? _previewDirectory;

  void setWorkspace(EditorWorkspace value) {
    if (workspace == value) return;
    workspace = value;
    notifyListeners();
    if (value == EditorWorkspace.viewer) unawaited(refreshViewer());
  }

  void setPropertiesTab(PropertiesTab value) {
    if (propertiesTab == value) return;
    propertiesTab = value;
    notifyListeners();
  }

  void setTargetDeviceProfile(DeviceProfile value) {
    if (identical(targetDeviceProfile, value)) return;
    targetDeviceProfile = value;
    notifyListeners();
  }

  Future<void> refreshViewer() async {
    final current = doc;
    if (current == null) return;
    final revision = ++_previewRevision;
    try {
      final document = coreDoc;
      final json = document != null
          ? comicsToCore(document)
          : <String, dynamic>{
              'width': current.width,
              'height': current.height,
              'layers': const <Object>[],
              'sounds': const <Object>[],
            };
      final data = utf8.encode(jsonEncode(json));
      final archive = Archive()
        ..addFile(ArchiveFile('data.json', data.length, data));
      final working = coreDoc?.tempFolder;
      if (working != null) {
        final root = Directory(working);
        if (root.existsSync()) {
          for (final entity
              in root.listSync(recursive: true).whereType<File>()) {
            final relative = entity.path.substring(root.path.length + 1);
            if (relative == 'data.json') continue;
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relative, bytes.length, bytes));
          }
        }
      }
      if (revision != _previewRevision) return;
      final encoded = ZipEncoder().encode(archive);
      final directory = _previewDirectory ??= Directory.systemTemp
          .createTempSync('comics_editor_viewer_');
      final target = File('${directory.path}/preview_$revision.comics');
      final staging = File('${target.path}.tmp');
      await staging.writeAsBytes(encoded, flush: true);
      await staging.rename(target.path);
      if (revision != _previewRevision) return;
      viewerSource = viewer.ComicsViewerPath(
        target.path,
        revisionKey: revision,
      );
      await viewerController.load(viewerSource!);
      notifyListeners();
    } on Exception catch (error) {
      coreError = 'Viewer preview failed: $error';
      notifyListeners();
    }
  }

  SelKind selKind = SelKind.none;
  int selIndex = -1;
  int selAnim = -1;

  // ---------- Layer.ParentId (tdd-dot-comics-format Plan Task 3.3) ----------

  /// View-only, like [mode]/[lang] -- never persisted. Collapsed parents
  /// hide their descendants from [hierarchicalLayerOrder].
  final Set<String> _collapsedLayerIds = {};

  bool isLayerCollapsed(String layerId) => _collapsedLayerIds.contains(layerId);

  void toggleLayerCollapsed(String layerId) {
    if (!_collapsedLayerIds.add(layerId)) _collapsedLayerIds.remove(layerId);
    notifyListeners();
  }

  /// True if [candidate] has at least one direct child in [layers].
  bool layerHasChildren(EditorLayer candidate, List<EditorLayer> layers) =>
      layers.any((l) => l.parentId == candidate.id);

  /// Depth-first render order: each root (no parent, or an orphaned/unknown
  /// parentId) in original document order, followed recursively by its own
  /// children in original document order -- returns (docIndex, depth) pairs.
  /// A document where no layer has a parentId produces the exact same order
  /// as today's flat list, by construction (every layer is a childless
  /// root).  Descendants of a collapsed parent are omitted entirely.
  List<(int, int)> hierarchicalLayerOrder(List<EditorLayer> layers) {
    final byId = {for (final l in layers) l.id: l};
    final result = <(int, int)>[];

    void visit(EditorLayer layer, int depth) {
      final index = layers.indexOf(layer);
      result.add((index, depth));
      if (_collapsedLayerIds.contains(layer.id)) return;
      for (final child in layers) {
        if (child.parentId == layer.id) visit(child, depth + 1);
      }
    }

    for (final layer in layers) {
      final parentId = layer.parentId;
      final hasKnownParent = parentId != null && byId.containsKey(parentId);
      if (!hasKnownParent) visit(layer, 0);
    }
    return result;
  }

  /// True if setting `child.parentId = candidateParentId` would create a
  /// cycle -- either directly (a layer parented to itself) or indirectly (a
  /// layer parented to one of its own descendants).
  bool wouldCreateParentCycle(
    EditorLayer child,
    String candidateParentId,
    List<EditorLayer> layers,
  ) {
    if (candidateParentId == child.id) return true;
    // Walk descendants of `child`; if any of them is `candidateParentId`,
    // parenting `child` under it would close a loop.
    bool visit(String currentId) {
      for (final l in layers) {
        if (l.parentId == currentId) {
          if (l.id == candidateParentId) return true;
          if (visit(l.id)) return true;
        }
      }
      return false;
    }
    return visit(child.id);
  }

  /// Sets or clears a layer's parent. No-op (does not mutate/notify) if it
  /// would create a cycle -- callers (the "Set parent..." picker) should
  /// already exclude cycle-creating choices, this is the last line of
  /// defense.
  void setLayerParent(EditorLayer child, String? parentId) {
    if (parentId != null &&
        wouldCreateParentCycle(child, parentId, doc!.layers)) {
      return;
    }
    _beginHistory();
    child.parentId = parentId;
    _commitHistory();
  }

  int playhead = 0; // current frame
  final int totalFrames = 600;

  // ---------- canvas viewport camera (view-only, not persisted) ----------
  static const double kCanvasZoomMin = 0.25;
  static const double kCanvasZoomMax = 4.0;
  static const double kCanvasZoomStep = 1.25;

  /// Pan/zoom transform applied on top of the fit-to-viewport page layout.
  /// Decoupled from [ComicsDoc.scale] (puzzle-only business field) — see
  /// sdd-comics-editor-v2.9-fixes1 Iteration 2.
  final TransformationController canvasViewport = TransformationController();

  /// Lets sibling widgets (e.g. the +/- zoom buttons) find the
  /// InteractiveViewer's RenderBox to compute a focal point for zoomBy().
  final GlobalKey viewportKey = GlobalKey();

  /// vdd-comics-editor-vertical-scroll: the single source of truth for
  /// keyframe "time" -- derived from [canvasViewport]'s pan position, in
  /// real document pixels, matching legacy's `ScrollViewer.VerticalOffset`
  /// (see 03-specifications.md's Data Flow). Deliberately does NOT replace
  /// [playhead] -- `timeline.dart` keeps reading/driving `playhead` exactly
  /// as before (an explicit, disclosed decision: Anton asked to leave
  /// `timeline.dart` untouched for now, and separately confirmed that new
  /// keyframes authored via `addAnim`/`addSound` should stamp real
  /// `currentTime` values, accepting that `timeline.dart`'s own 0..600
  /// frame-scaled rendering will show those newly-authored bars off-scale
  /// until it gets its own redesign later). `playhead` is therefore now
  /// fully vestigial for anything except that widget's own display.
  ///
  /// First-pass formula (flagged in 03-specifications.md's Open Design
  /// Questions as needing empirical zoom-invariance verification, refined in
  /// Plan Task 3.3 once the real fit-width canvas layout lands): divides out
  /// [canvasViewport]'s own zoom so the value is proportional to real
  /// document pixels regardless of zoom level. Sign convention: panning
  /// down (revealing lower content) moves content up on screen, i.e. the
  /// transform's Y translation becomes more negative -- negating it here
  /// makes `currentTime` increase as you scroll further down, matching
  /// legacy's `Scroll` increasing with `VerticalOffset`.
  double get currentTime {
    final zoom = canvasViewport.value.getMaxScaleOnAxis();
    if (zoom == 0) return 0;
    final ty = canvasViewport.value.getTranslation().y;
    return -ty / zoom;
  }

  // ---------- sound playback (Task 4.3) ----------
  // Mirrors ComicsViewModel.Scroll's per-tick `sound.Scroll()` call
  // (native/Comics.Editor/ViewModel/ComicsViewModel.cs:169-170) -- one
  // SoundPlayer per EditorSound, evaluated every time currentTime changes.
  final Map<EditorSound, SoundPlayer> _soundPlayers = {};
  double _prevSoundTime = 0;

  void _onSoundTick() {
    final t = currentTime;
    final tempFolder = coreDoc?.tempFolder;
    final sounds = doc?.sounds;
    if (tempFolder != null && sounds != null) {
      for (final s in sounds) {
        // FileManager.FolderSounds = "sounds" (legacy/comics-editor-v2.8/
        // Comics.Editor/Utils/FileManager.cs:18) -- same tempFolder/<kind>/
        // shape as images' tempFolder/layers/.
        final player = _soundPlayers.putIfAbsent(
          s,
          () => SoundPlayer('$tempFolder/sounds/${s.file}'),
        );
        player.evaluate(s.anims, _prevSoundTime, t);
      }
    }
    _prevSoundTime = t;
  }

  void resetViewport() {
    canvasViewport.value = Matrix4.identity();
  }

  /// Zooms by [factor] (multiplicative) around [focalPoint], given in the
  /// InteractiveViewer's local coordinate space.
  void zoomBy(double factor, Offset focalPoint) {
    final current = canvasViewport.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(kCanvasZoomMin, kCanvasZoomMax);
    final scaleDelta = target / current;
    if (scaleDelta == 1.0) return;
    final scenePoint = canvasViewport.toScene(focalPoint);
    canvasViewport.value = canvasViewport.value.clone()
      ..translateByDouble(scenePoint.dx, scenePoint.dy, 0, 1)
      ..scaleByDouble(scaleDelta, scaleDelta, scaleDelta, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);
  }

  // ---------- undo/redo (see sdd-comics-editor-v2.9-fixes2) ----------
  final EditHistory _history = EditHistory();
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Snapshot the current doc BEFORE a mutation. No-op if no doc is open.
  /// Call right after any early-return guards, so no-op calls (e.g.
  /// moveLayer() at a boundary) don't create phantom history entries.
  void _beginHistory() {
    final d = doc;
    if (d != null) _history.beginTransaction(d.clone());
  }

  void _commitHistory() {
    _history.commitTransaction();
  }

  /// Public transaction boundary for continuous gestures (e.g. layer drag in
  /// canvas_view.dart) — one history entry per whole gesture, not per frame.
  void beginGestureHistory() => _beginHistory();
  void commitGestureHistory() => _commitHistory();

  void undo() {
    final d = doc;
    if (d == null) return;
    final snapshot = _history.undo(d.clone());
    if (snapshot == null) return;
    doc = snapshot;
    final cd = coreDoc;
    if (cd != null) coreDoc = CoreDocument(snapshot, cd.raw, cd.path);
    _clearSelection();
    notifyListeners();
  }

  void redo() {
    final d = doc;
    if (d == null) return;
    final snapshot = _history.redo(d.clone());
    if (snapshot == null) return;
    doc = snapshot;
    final cd = coreDoc;
    if (cd != null) coreDoc = CoreDocument(snapshot, cd.raw, cd.path);
    _clearSelection();
    notifyListeners();
  }

  bool get isOpen => doc != null;
  bool get isPuzzle => doc?.type == DocType.puzzle;

  EditorLayer? get selectedLayer =>
      selKind == SelKind.layer ? doc!.layers[selIndex] : null;
  EditorSound? get selectedSound =>
      selKind == SelKind.sound ? doc!.sounds[selIndex] : null;

  List<Anim> get selectedAnims =>
      selectedLayer?.anims ?? selectedSound?.anims ?? const [];
  Anim? get currentAnim => (selAnim >= 0 && selAnim < selectedAnims.length)
      ? selectedAnims[selAnim]
      : null;

  // ---- recent files for the Open dialog ----
  static const recents = <RecentFile>[
    RecentFile(
      'beach.comics',
      DocType.comics,
      'Comics · 1080×1920 · edited today',
    ),
    RecentFile(
      'city.comics',
      DocType.comics,
      'Comics · 1080×1920 · 3 days ago',
    ),
    RecentFile(
      'island.puzzle',
      DocType.puzzle,
      'Puzzle · 1024×768 · last week',
    ),
    RecentFile(
      'maze.puzzle',
      DocType.puzzle,
      'Puzzle · 1024×768 · 2 weeks ago',
    ),
  ];

  // ---------- v2.9: реальные файлы через headless-ядро ----------
  final ComicsCore core = createComicsCore();
  CoreDocument? coreDoc;
  String? coreError;

  /// Reports a failure that occurred before [openPath] could reach the core,
  /// such as an unreadable operating-system document URI.
  void reportExternalOpenError(String message) {
    coreError = message;
    notifyListeners();
  }

  bool get coreAvailable => core.isAvailable;

  /// tdd-dot-lottie-import-export Plan Task 6.2: non-null exactly while the
  /// review dialog is open. Building this is pure (`ImportPreview.build`
  /// has no side effects), so simply discarding it (see [cancelLottieImport])
  /// is a true no-op -- Test A4.
  ImportPreview? lottiePreview;

  /// Set only when [pickLottieToImport] fails to parse the picked file
  /// (Test F1) -- shown by the review dialog in place of the preview.
  String? lottieImportError;

  // vdd-comics-editor-uiux-lettering: dynamic language list (Task 1.4),
  // loaded once and cached -- backs Images[] slot resolution beyond en/ru/hi
  // (Task 1.2) in setImageFile/setImagePopup below.
  //
  // Deliberately NOT an `async` getter (`Future<T> get x async => ...`):
  // every *call* to an async function/getter allocates a brand-new Future
  // for that invocation, even when the body resolves to an already-cached
  // value -- so widgets that pass `c.languageRegistry` straight into a
  // `FutureBuilder`'s `future:` (Task 4.3's balloon section, Task 5.3's
  // Lettering layout) would get a different Future *instance* on every
  // rebuild, and FutureBuilder treats a changed `future` as "start waiting
  // again", discarding whatever it already resolved. Caching the Future
  // object itself (not just the eventual value) keeps repeated accesses
  // returning the exact same instance, so FutureBuilder settles once.
  Future<LanguageRegistry>? _languageRegistryFuture;
  Future<LanguageRegistry> get languageRegistry =>
      _languageRegistryFuture ??= LanguageRegistry.load();

  /// vdd-comics-editor-uiux-lettering, Task 4.3: client-side AI contract for
  /// balloon generation (Task 4.1). Stub-backed for now -- no real
  /// on-device/cloud engine exists yet (03-specifications.md scopes this
  /// flow to the client contract only), but `BalloonEditorCard` needs a
  /// concrete instance to render, and swapping in a real implementation
  /// later is just replacing this one field, not touching UI code.
  final BalloonAiClient aiClient = StubBalloonAiClient();

  /// vdd-comics-editor-ai-uiux: client for the multimodal cutting/segmentation pipeline
  /// (Cutting mode). Stub-backed on platforms/tests that don't spawn the real subprocess;
  /// desktop UI wiring replaces this with a real `ProcessCuttingClient` (Task 6.1).
  cutting.MultimodalCuttingClient cuttingClient = StubCuttingClient();

  /// vdd-comics-editor-ai-uiux, Task 3.1: current Cutting-mode session, if any. Null when Cutting
  /// mode has never been triggered (or was reset) for the open document.
  CuttingSession? cuttingSession;
  StreamSubscription<cutting.CuttingEvent>? _cuttingSubscription;

  /// Overridable for tests, so `insertIntoLibrary` doesn't write into the real, shared
  /// `apps/comics-ai/comics-multimodal/work/library/` directory during a test run -- same
  /// testability seam as `ProcessCuttingClient`'s resolver overrides (Task 2.4), needed because
  /// `Platform.environment` can't be mutated from within a running Dart process either.
  String? Function() resolveLibraryDir = MultimodalPaths.resolveLibraryDir;

  /// Открывает .comics/.puzzle через Comics.Editor.Headless.
  Future<bool> openPath(String path) async {
    try {
      final result =
          await core.call('openComics', {'path': path}) as Map<String, dynamic>;
      coreDoc = comicsFromCore(
        result['comics'] as Map<String, dynamic>,
        path,
        tempFolder: result['tempFolder'] as String?,
      );
      doc = coreDoc!.doc;
      _resetWorkspaceState();
      coreError = null;
      resetViewport();
      _clearSelection();
      if (doc!.layers.isNotEmpty) selectLayer(0);
      notifyListeners();
      return true;
    } on Exception catch (e) {
      coreError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Открытие через системный диалог (file_picker, все платформы).
  Future<bool> openWithDialog() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['comics', 'puzzle'],
    );
    final path = result?.files.single.path;
    if (path == null) return false; // отмена — не ошибка
    return openPath(path);
  }

  /// Export / Save As: системный диалог места сохранения.
  /// Desktop: диалог возвращает путь → ядро пишет по нему.
  /// Mobile: ядро пишет во временный файл → байты → системный диалог (SAF/Files).
  Future<bool> exportWithDialog() async {
    final document = coreDoc;
    if (document == null) return false;
    final fileName = document.doc.name.isEmpty
        ? 'untitled.comics'
        : document.doc.name;
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        final tempPath =
            '${Directory.systemTemp.createTempSync('comics_export').path}/$fileName';
        await core.call('saveComics', {
          'path': tempPath,
          'comics': comicsToCore(document),
        });
        final saved = await FilePicker.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['comics', 'puzzle'],
          bytes: await File(tempPath).readAsBytes(),
        );
        return saved != null;
      }
      final path = await FilePicker.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['comics', 'puzzle'],
      );
      if (path == null) return false; // отмена
      return saveToPath(path);
    } on Exception catch (e) {
      coreError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Сохраняет текущий документ (открытый через [openPath]) в .comics/.puzzle.
  /// На мобильных без явного пути пишет в песочницу приложения (решение Q4):
  /// системный picker отдаёт временную копию, писать в неё бессмысленно.
  Future<bool> saveToPath([String? path]) async {
    final document = coreDoc;
    if (document == null) return false;
    try {
      var target = path ?? document.path;
      if (path == null && (Platform.isIOS || Platform.isAndroid)) {
        target = await DocumentsStore.pathFor(document.doc.name);
        document.path = target;
      }
      await core.call('saveComics', {
        'path': target,
        'comics': comicsToCore(document),
      });
      if (path != null) document.path = path;
      coreError = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      coreError = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    canvasViewport.removeListener(_onSoundTick);
    for (final player in _soundPlayers.values) {
      player.dispose();
    }
    canvasViewport.dispose();
    viewerController.dispose();
    final previewDirectory = _previewDirectory;
    if (previewDirectory != null && previewDirectory.existsSync()) {
      previewDirectory.deleteSync(recursive: true);
    }
    core.dispose();
    super.dispose();
  }

  // ---------- document lifecycle ----------
  // tdd-dot-comics-format Plan Task 2.3: New Document dialog selections,
  // both independent of `type` and of each other -- default to the
  // backward-compat values so every existing call site (that doesn't pass
  // them) is unaffected.
  void newDoc(
    DocType type, {
    ScrollType scrollType = ScrollType.vertical,
    PreferredOrientation preferredOrientation = PreferredOrientation.portrait,
  }) {
    coreDoc = null;
    doc = ComicsDoc(
      name: type == DocType.comics ? 'untitled.comics' : 'untitled.puzzle',
      type: type,
      width: type == DocType.comics ? 1080 : 1024,
      height: type == DocType.comics ? 1920 : 768,
    )
      ..scrollType = scrollType
      ..preferredOrientation = preferredOrientation;
    _history.clear();
    _resetWorkspaceState();
    resetViewport();
    _clearSelection();
    notifyListeners();
  }

  void openRecent(RecentFile f) {
    coreDoc = null;
    doc = ComicsDoc(
      name: f.name,
      type: f.type,
      width: f.type == DocType.comics ? 1080 : 1024,
      height: f.type == DocType.comics ? 1920 : 768,
    );
    _history.clear();
    _resetWorkspaceState();
    resetViewport();
    if (f.name == 'beach.comics') _seedBeach();
    _clearSelection();
    if (doc!.layers.isNotEmpty) selectLayer(doc!.layers.length - 2 < 0 ? 0 : 2);
    notifyListeners();
  }

  void _resetWorkspaceState() {
    workspace = EditorWorkspace.editor;
    propertiesTab = PropertiesTab.selection;
    viewerSource = null;
    _previewRevision++;
  }

  /// The sample scene used across the mockups.
  void _seedBeach() {
    final d = doc!;
    d.layers
      ..add(
        EditorLayer('sky.png', at: const Offset(0, -40))
          ..swatch = const Color(0xFF2C4256)
          ..size = 1.0,
      )
      ..add(
        EditorLayer('clouds.png', at: const Offset(40, 120))
          ..swatch = const Color(0xFF4E555C)
          ..size = .5,
      )
      ..add(
        EditorLayer('hero.png', at: const Offset(70, 210))
          ..swatch = const Color(0xFF57422D)
          ..size = .55
          ..anims.add(Anim(AnimType.rotate, start: 210, end: 360)..angle = 45)
          ..anims.add(Anim(AnimType.alpha, start: 360, end: 480)..alpha = .5),
      )
      ..add(
        EditorLayer('foreground.png', at: const Offset(0, 430))
          ..swatch = const Color(0xFF374A32)
          ..size = 1.0
          ..visible = false,
      );
    d.sounds
      ..add(
        EditorSound('wind.mp3')
          ..anims.add(Anim(AnimType.sound, start: 140, end: 320)),
      )
      ..add(
        EditorSound('wave.mp3')
          ..anims.add(Anim(AnimType.sound, start: 420, end: 560)),
      );
  }

  void setLanguage(Lang l) {
    lang = l;
    notifyListeners();
  }

  /// vdd-comics-editor-uiux-lettering, Task 5.1: Edit/Lettering mode switch
  /// (top bar). View-only, not persisted -- same treatment as [lang].
  EditorMode mode = EditorMode.edit;
  void setMode(EditorMode m) {
    if (mode == m) return;
    mode = m;
    if (m == EditorMode.lettering) _ensureBalloonSelected();
    notifyListeners();
  }

  /// Task 5.3: "Lands on the first balloon ... if all are complete" --
  /// simplified to "first balloon/caption layer in document order" rather
  /// than discerning per-language artwork completeness here, which would
  /// need a target language + LanguageRegistry this controller-level method
  /// doesn't have handy; the rail lets the user jump anywhere in one tap
  /// regardless. No-op if the current selection is already a balloon/caption,
  /// or if the document has none.
  void _ensureBalloonSelected() {
    final indices = _balloonIndices();
    if (indices.isEmpty) return;
    if (selKind == SelKind.layer && indices.contains(selIndex)) return;
    selectLayer(indices.first);
  }

  void toggleMode() =>
      setMode(mode == EditorMode.edit ? EditorMode.lettering : EditorMode.edit);

  /// vdd-comics-editor-uiux-lettering, Task 5.5: deselects the current layer
  /// without leaving Lettering mode -- backs the iPhone two-screen flow's
  /// "< Balloons" button (balloon editor screen -> balloon list screen).
  void deselectForLettering() {
    _clearSelection();
    notifyListeners();
  }

  List<int> _balloonIndices() {
    final d = doc;
    if (d == null) return const [];
    bool isBalloonKind(EditorLayer l) =>
        l.kind == 'balloon' || l.kind == 'caption';
    return [
      for (var i = 0; i < d.layers.length; i++)
        if (isBalloonKind(d.layers[i])) i,
    ];
  }

  /// vdd-comics-editor-uiux-lettering, Task 5.6: 1-based `(position, total)`
  /// among balloon/caption layers in document order (the same order
  /// [BalloonRail] lists them) for the current selection -- backs the
  /// `N/M` counter shown alongside prev/next. Null if nothing selected, the
  /// selection isn't a balloon/caption layer, or the document has none.
  ({int position, int total})? balloonStepInfo() {
    final indices = _balloonIndices();
    if (indices.isEmpty || selKind != SelKind.layer) return null;
    final pos = indices.indexOf(selIndex);
    if (pos == -1) return null;
    return (position: pos + 1, total: indices.length);
  }

  /// Steps the selection to the next ([direction] > 0) or previous
  /// ([direction] < 0) balloon/caption layer, without leaving Lettering
  /// mode. Clamped at the ends (no wraparound) -- a no-op past the first/
  /// last balloon, or if the document has none. If nothing balloon-like is
  /// currently selected, starts from the first one.
  void stepBalloon(int direction) {
    final indices = _balloonIndices();
    if (indices.isEmpty) return;
    final currentPos = selKind == SelKind.layer
        ? indices.indexOf(selIndex)
        : -1;
    final nextPos = (currentPos == -1 ? 0 : currentPos + direction).clamp(
      0,
      indices.length - 1,
    );
    selectLayer(indices[nextPos]);
  }

  void toggleMute() {
    muted = !muted;
    notifyListeners();
  }

  void setCanvasSize(int? w, int? h) {
    if (doc == null) return;
    _beginHistory();
    if (w != null) doc!.width = w;
    if (h != null) doc!.height = h;
    _commitHistory();
    notifyListeners();
  }

  void previewCanvasSize(int? w, int? h) {
    if (doc == null) return;
    if (w != null) doc!.width = w;
    if (h != null) doc!.height = h;
    notifyListeners();
  }

  void setScale(double s) {
    if (doc == null) return;
    _beginHistory();
    doc?.scale = s;
    _commitHistory();
    notifyListeners();
  }

  void previewScale(double value) {
    if (doc == null) return;
    doc!.scale = value;
    notifyListeners();
  }

  void setPlayhead(int frame) {
    playhead = frame.clamp(0, totalFrames);
    notifyListeners();
  }

  // ---------- selection ----------
  void _clearSelection() {
    selKind = SelKind.none;
    selIndex = -1;
    selAnim = -1;
  }

  void selectLayer(int i) {
    selKind = SelKind.layer;
    selIndex = i;
    selAnim = doc!.layers[i].anims.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  void selectSound(int i) {
    selKind = SelKind.sound;
    selIndex = i;
    selAnim = doc!.sounds[i].anims.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  void selectAnim(int i) {
    selAnim = i;
    notifyListeners();
  }

  // ---------- layers ----------
  void addLayer() {
    final d = doc!;
    _beginHistory();
    final l =
        EditorLayer(
            'layer_${d.layers.length + 1}.png',
            at: Offset(40, 60.0 + d.layers.length * 30),
          )
          ..swatch = Colors
              .primaries[d.layers.length % Colors.primaries.length]
              .shade700;
    d.layers.add(l);
    _commitHistory();
    selectLayer(d.layers.length - 1);
  }

  // tdd-dot-comics-format Plan Task 3.5: a non-content layer that exists
  // purely to be a parentId target or to organize -- no artwork, so images
  // (auto-seeded by the EditorLayer constructor) is cleared right after.
  void addOrganizationalLayer() {
    final d = doc!;
    _beginHistory();
    final l =
        EditorLayer(
            'anchor_${d.layers.length + 1}',
            at: Offset(40, 60.0 + d.layers.length * 30),
          )
          ..kind = EditorLayer.organizationalKind;
    l.images.clear();
    d.layers.add(l);
    _commitHistory();
    selectLayer(d.layers.length - 1);
  }

  // tdd-dot-comics-format Plan Task 4.3: a layer that renders as a flat
  // color fill instead of a raster image. `images` is left populated by the
  // constructor (never cleared) -- solidColor takes precedence for
  // rendering per models.dart's own doc comment, so nothing is lost if the
  // author later clears solidColor and wants the image slots back.
  void addSolidColorLayer(String hexColor) {
    final d = doc!;
    _beginHistory();
    final l =
        EditorLayer(
            'solid_${d.layers.length + 1}',
            at: Offset(40, 60.0 + d.layers.length * 30),
          )
          ..solidColor = hexColor;
    d.layers.add(l);
    _commitHistory();
    selectLayer(d.layers.length - 1);
  }

  void moveLayer(int dir) {
    if (selKind != SelKind.layer) return;
    final i = selIndex, j = i + dir;
    final ls = doc!.layers;
    if (j < 0 || j >= ls.length) return;
    _beginHistory();
    final tmp = ls[i];
    ls[i] = ls[j];
    ls[j] = tmp;
    selIndex = j;
    _commitHistory();
    notifyListeners();
  }

  void deleteSelected() {
    if (selKind != SelKind.layer && selKind != SelKind.sound) return;
    _beginHistory();
    if (selKind == SelKind.layer) {
      final removed = doc!.layers.removeAt(selIndex);
      // tdd-dot-comics-format Plan Task 3.1, orphan policy: clear parentId
      // on any child, keep its last-resolved absolute position -- no
      // re-computation, no cascade delete.
      for (final layer in doc!.layers) {
        if (layer.parentId == removed.id) layer.parentId = null;
      }
    } else {
      doc!.sounds.removeAt(selIndex);
    }
    _clearSelection();
    _commitHistory();
    notifyListeners();
  }

  void toggleVisible(int i) {
    _beginHistory();
    doc!.layers[i].visible = !doc!.layers[i].visible;
    _commitHistory();
    notifyListeners();
  }

  void togglePreview() {
    final l = selectedLayer;
    if (l == null) return;
    _beginHistory();
    l.preview = !l.preview;
    _commitHistory();
    notifyListeners();
  }

  /// vdd-comics-editor-uiux-lettering, Task 3.2: sets/clears the selected
  /// layer's coarse `kind` (local mutation, same shape as [setImageFile] --
  /// no RPC, per the Phase 2 correction). `null` clears it back to today's
  /// untyped/generic layer.
  void setLayerKind(String? kind) {
    final l = selectedLayer;
    if (l == null) return;
    _beginHistory();
    l.kind = kind;
    _commitHistory();
    notifyListeners();
  }

  // tdd-dot-comics-format Plan Task 4.3: MASK section's shape selector.
  // `null` = None (today's exact behavior, full unclipped content). Only
  // "rect" has real editing UI; a fresh rect defaults to a visible-sized
  // placeholder the author immediately sees and can adjust.
  void setLayerMaskShape(String? shape) {
    final l = selectedLayer;
    if (l == null) return;
    _beginHistory();
    l.mask = switch (shape) {
      null => null,
      'rect' => LayerMask.rect(const Rect.fromLTWH(0, 0, 100, 100)),
      _ => LayerMask(shape: shape),
    };
    _commitHistory();
    notifyListeners();
  }

  /// Live preview while dragging a mask rect field -- bracketed by
  /// [beginGestureHistory]/[commitGestureHistory] at the call site, same
  /// contract as [previewCanvasSize].
  void previewLayerMaskRect(Rect rect) {
    final l = selectedLayer;
    if (l == null) return;
    l.mask = LayerMask.rect(rect);
    notifyListeners();
  }

  /// Direct commit (e.g. typing a value), own history transaction -- same
  /// contract as [setCanvasSize].
  void setLayerMaskRect(Rect rect) {
    final l = selectedLayer;
    if (l == null) return;
    _beginHistory();
    l.mask = LayerMask.rect(rect);
    _commitHistory();
    notifyListeners();
  }

  /// vdd-comics-editor-uiux-lettering, Task 4.2: sets/clears the selected
  /// layer's balloon text for [langCode] (local mutation, same shape as
  /// [setLayerKind]). An empty [text] removes the entry -- mirrors
  /// `Layer.Translations`' dictionary semantics, where an empty value is
  /// indistinguishable from unset.
  void setLayerTranslation(String langCode, String text) {
    final l = selectedLayer;
    if (l == null) return;
    _beginHistory();
    if (text.isEmpty) {
      l.translations.remove(langCode);
    } else {
      l.translations[langCode] = text;
    }
    _commitHistory();
    notifyListeners();
  }

  /// Drag the selected layer around the canvas (Translate). tdd-dot-comics-
  /// format Plan Task 3.4: every parentId descendant moves live by the same
  /// delta, so a parented rig (e.g. голова -> руки сложен -> предплечье)
  /// drags as one rigid unit -- a no-op walk for every document that has no
  /// parentId set, i.e. today's exact behavior.
  void dragSelected(Offset delta) {
    final l = selectedLayer;
    if (l == null) return;
    l.translate += delta;
    _dragDescendants(l, delta);
    notifyListeners();
  }

  void _dragDescendants(EditorLayer parent, Offset delta) {
    for (final child in doc!.layers) {
      if (child.parentId == parent.id) {
        child.translate += delta;
        _dragDescendants(child, delta);
      }
    }
  }

  /// vdd-comics-editor-uiux-lettering, Task 2.3: tile-writes real artwork
  /// [bytes] (from a file pick or AI generation) into the document's
  /// tempFolder (Task 2.2) and points the [langCode] Images[] slot (resolved
  /// via the LanguageRegistry, Task 1.2) at it. Replaces the old
  /// hardcoded-placeholder-filename stub, which never wrote real bytes at
  /// all. No-op if there's no selected layer or no backing core session
  /// (tempFolder unset) -- e.g. a document opened before a core existed.
  Future<void> setImageFile(String langCode, Uint8List bytes) async {
    final layer = selectedLayer;
    final document = coreDoc;
    final tempFolder = document?.tempFolder;
    if (layer == null || document == null || tempFolder == null) return;

    final registry = await languageRegistry;
    final index = registry.indexFor(langCode);
    if (index == null) return;
    final slot = layer.imageSlotFor(langCode, registry);

    final layersDir = '$tempFolder/layers';
    await deleteTiles(layersDir, slot.file.isEmpty ? null : slot.file);
    final tiled = await writeTiles(
      bytes: bytes,
      layersDir: layersDir,
      name: '${sanitizeStem(layer.name)}_$langCode',
    );

    _beginHistory();
    slot.file = tiled.fileTemplate;
    _commitHistory();
    setImageDimensions(document, selIndex, index, tiled.width, tiled.height);
    notifyListeners();
  }

  /// Same as [setImageFile] but for `Popup` -- unlike `File`, popups are
  /// never split into 512px tiles (`Image.Update`'s `popup: true` branch
  /// calls `FileManager.Update`, a plain single-file copy) and carry no
  /// tracked width/height in the JSON.
  Future<void> setImagePopup(String langCode, Uint8List bytes) async {
    final layer = selectedLayer;
    final document = coreDoc;
    final tempFolder = document?.tempFolder;
    if (layer == null || document == null || tempFolder == null) return;

    final registry = await languageRegistry;
    final slot = layer.imageSlotFor(langCode, registry);

    final layersDir = '$tempFolder/layers';
    await deleteSingleFile(layersDir, slot.popup.isEmpty ? null : slot.popup);
    final fileName = await writeSingleFile(
      bytes: bytes,
      layersDir: layersDir,
      name: '${sanitizeStem(layer.name)}_${langCode}_popup',
    );

    _beginHistory();
    slot.popup = fileName;
    _commitHistory();
    notifyListeners();
  }

  /// vdd-comics-editor-uiux-lettering, Task 6.1: real file-picker dialog for
  /// the generic "ARTWORK · PER LANGUAGE" section's `File`/`Popup` fields --
  /// previously a stub that wrote a fake, never-actually-saved placeholder
  /// filename. Reads real bytes and writes them through the same tile-write
  /// path Task 2.3 built for AI-generated artwork. Returns false on cancel
  /// (not an error) or if there's nothing to write to yet (no open document).
  Future<bool> pickImageFile(String langCode) async {
    if (selectedLayer == null || coreDoc?.tempFolder == null) return false;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false; // отмена — не ошибка
    await setImageFile(langCode, bytes);
    return true;
  }

  /// Same as [pickImageFile] but for `Popup`.
  Future<bool> pickImagePopup(String langCode) async {
    if (selectedLayer == null || coreDoc?.tempFolder == null) return false;
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false;
    await setImagePopup(langCode, bytes);
    return true;
  }

  // ---------- .lottie import/export (tdd-dot-lottie-import-export) ----------

  /// Plan Task 6.1/6.2: picks a `.lottie` file and builds its [ImportPreview]
  /// (mode auto-detected, per Task 3.1) -- pure, no `.comics` mutation yet.
  /// The caller (the review dialog) shows [lottiePreview] and eventually
  /// calls [commitLottieImport] or [cancelLottieImport]. Returns `false` on
  /// cancel (not an error, per this app's own established convention) or on
  /// a parse failure (Test F1) -- [lottieImportError] carries the message
  /// for the latter so the dialog can show it instead of a preview.
  Future<bool> pickLottieToImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['lottie'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false; // отмена — не ошибка
    lottieImportError = null;
    try {
      final document = parseLottieDocument(bytes);
      lottiePreview = ImportPreview.build(document, detectMode(document));
    } on LottieFormatException catch (e) {
      lottieImportError = e.toString();
      lottiePreview = null;
    }
    notifyListeners();
    return true;
  }

  /// Task 6.3 (mode override): rebuilds [lottiePreview] under [mode] instead
  /// of the auto-detected one -- classification itself is mode-dependent
  /// (`ImportPreview.build`'s own two branches), so this can't just flip a
  /// flag on the existing preview. A fresh `scrollSpeed` re-derives for
  /// playbackViewport; any user edit to it from before the override is
  /// intentionally not preserved, since a mode change invalidates it anyway
  /// (Full Canvas has no such field at all).
  void setLottieImportMode(ExportImportMode mode) {
    final preview = lottiePreview;
    if (preview == null || preview.mode == mode) return;
    lottiePreview = ImportPreview.build(preview.document, mode)..easing = preview.easing;
    notifyListeners();
  }

  void setLottieScrollSpeed(double speed) {
    lottiePreview?.scrollSpeed = speed;
    notifyListeners();
  }

  void setLottieEasingChoice(EasingChoice easing) {
    final preview = lottiePreview;
    if (preview == null) return;
    preview.easing = easing;
    notifyListeners();
  }

  /// Test A4: cancel is a true no-op -- [lottiePreview] is discarded before
  /// any `.comics` mutation has happened (`ImportPreview.build` is pure), so
  /// there is nothing to roll back.
  void cancelLottieImport() {
    lottiePreview = null;
    lottieImportError = null;
    notifyListeners();
  }

  /// Plan Task 4.1/4.2 (`commitImport`) + Task 6.4 (real image-byte
  /// extraction), wired together at the one level that has both a real
  /// `ComicsDoc` to mutate and (when available) a real `CoreDocument
  /// .tempFolder` to write tiles into. One history transaction for the
  /// whole import, so a single Undo reverts every layer it added.
  ///
  /// **Real, disclosed scope boundary** (same one `commitImport`'s own doc
  /// comment flags): without a `tempFolder` (e.g. importing into a brand
  /// new, never-saved document -- this app has no `newComics` core call, so
  /// [newDoc] never gets one either, an existing limitation every other
  /// tile-writing feature already shares, not new here), every imported
  /// layer keeps its placeholder image, matching `commitImport`'s own
  /// documented fallback. When a `tempFolder` *is* available, only clean
  /// image layers whose source asset is a base64 data URI get real pixels --
  /// every real `.lottie` file found embeds images this way (confirmed in
  /// Phase 2); the external-file-reference branch has no real content to
  /// exercise and is skipped (that layer keeps its placeholder), not guessed
  /// at with unread bytes.
  Future<bool> commitLottieImport() async {
    final preview = lottiePreview;
    final document = doc;
    if (preview == null || document == null) return false;

    _beginHistory();
    final startIndex = document.layers.length;
    commitImport(preview, document);

    final tempFolder = coreDoc?.tempFolder;
    if (tempFolder != null) {
      final cleanPreviews =
          preview.layers.where((l) => l.status == LayerPreviewStatus.clean).toList();
      final createdLayers = document.layers.sublist(startIndex);
      final assetsById = {for (final a in preview.document.assets) a.id: a};
      final layersDir = '$tempFolder/layers';
      for (var i = 0; i < createdLayers.length; i++) {
        final asset = assetsById[cleanPreviews[i].sourceLayer.refId];
        final bytes = _decodeDataUri(asset?.imagePath);
        if (bytes == null) continue;
        final tiled = await writeTiles(
          bytes: bytes,
          layersDir: layersDir,
          name: sanitizeStem(createdLayers[i].name),
        );
        createdLayers[i].images[0].file = tiled.fileTemplate;
      }
    }
    _commitHistory();

    lottiePreview = null;
    _clearSelection();
    notifyListeners();
    return true;
  }

  /// `null` for anything that isn't a `data:...;base64,<payload>` URI --
  /// covers both "no source asset found" and the disclosed external-file
  /// gap above.
  Uint8List? _decodeDataUri(String? imagePath) {
    if (imagePath == null || !imagePath.startsWith('data:')) return null;
    final commaIndex = imagePath.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64.decode(imagePath.substring(commaIndex + 1));
    } on FormatException {
      return null;
    }
  }

  /// Plan Task 6.1: the "easy direction" (per `lottie_export.dart`'s own
  /// doc comment) -- deterministic, no review screen. [mode] isn't
  /// auto-detected on export the way import's is (there's no analogous
  /// real-file signal to detect from a `ComicsDoc`); the caller (the export
  /// dialog) asks the user directly, defaulting to Full Canvas as the
  /// always-unambiguous choice.
  Future<bool> exportLottieWithDialog(
    ExportImportMode mode, {
    double? scrollSpeed,
  }) async {
    final document = doc;
    if (document == null) return false;
    try {
      final lottieDoc = buildLottieExport(
        document,
        mode,
        scrollSpeed: scrollSpeed,
        easing: EasingChoice.easyEaseApproximation,
      );
      final bytes = writeLottieDocument(lottieDoc, assetFiles: const []);
      final fileName =
          '${sanitizeStem(document.name.isEmpty ? 'untitled' : document.name)}.lottie';
      // `saveFile` writes `bytes` itself once the user picks a destination
      // (confirmed across every desktop platform implementation, and
      // required on mobile) -- no separate manual write needed here.
      final path = await FilePicker.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['lottie'],
        bytes: bytes,
      );
      return path != null;
    } on Exception catch (e) {
      coreError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ---------- cutting (vdd-comics-editor-ai-uiux) ----------

  /// vdd-comics-editor-ai-uiux, Task 3.1: starts a new [CuttingSession] against
  /// [sourceImageBytes] (the staged source image/layer at [sourceLayerIndex]), cancelling any
  /// in-flight session first. Local state only -- no RPC, per 03-specifications.md Finding 1.
  void triggerCutting(Uint8List sourceImageBytes, int sourceLayerIndex) {
    unawaited(_cuttingSubscription?.cancel());
    final document = coreDoc;
    final sourceLayer = doc != null && sourceLayerIndex < doc!.layers.length
        ? doc!.layers[sourceLayerIndex]
        : null;
    final hasArtwork = sourceLayer != null && sourceLayer.images.isNotEmpty;
    final dims = document == null
        ? null
        : imageDimensions(document, sourceLayerIndex, 0);
    final session = CuttingSession(
      sourceImageBytes: sourceImageBytes,
      sourceLayerIndex: sourceLayerIndex,
      sourceFileRef: hasArtwork ? sourceLayer.images.first.file : '',
      sourceWidth: dims?.width ?? 0,
      sourceHeight: dims?.height ?? 0,
    );
    cuttingSession = session;
    notifyListeners();

    _cuttingSubscription = cuttingClient
        .segment(sourceImageBytes: sourceImageBytes)
        .listen((event) {
          // Ignore events from a session that's since been replaced/cancelled (cuttingSession was
          // reassigned or cleared) -- this closure captured `session`, not the live field.
          if (!identical(cuttingSession, session)) return;
          switch (event) {
            case cutting.RoutingDecided(:final onDevice, :final reason):
              session.onDevice = onDevice;
              session.routingReason = reason;
            case cutting.Progress(:final stage):
              session.stage = stage;
            case cutting.Success(:final regions):
              session.regions = regions
                  .map((r) => PendingRegion(region: r))
                  .toList();
              session.stage = null;
              session.completed = true;
            case cutting.Failure(:final reason, :final retryable):
              session.failureReason = reason;
              session.failureRetryable = retryable;
              session.stage = null;
              session.completed = true;
          }
          notifyListeners();
        });
  }

  /// Cancels an in-flight session (kills the subprocess via [ProcessCuttingClient]'s
  /// `onCancel`) and clears it back to Cutting mode's trigger/empty state -- per `02-visual.md`'s
  /// Running state Cancel button, no partial regions are kept.
  void cancelCutting() {
    unawaited(_cuttingSubscription?.cancel());
    _cuttingSubscription = null;
    cuttingSession = null;
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux: detects the "source image changed after regions were generated"
  /// edge case (03-specifications.md's Edge Cases table / `02-visual.md`'s stale-output banner).
  /// Cheap and safe to call from a widget's `build()` -- only reads already-in-memory state
  /// (`imageDimensions` reads the raw JSON map, no disk I/O), no different from reading any other
  /// controller field. No-op if there's no session or no open document.
  void refreshCuttingStaleness() {
    final session = cuttingSession;
    final document = coreDoc;
    if (session == null || document == null) return;

    final layers = doc!.layers;
    bool isStale;
    if (session.sourceLayerIndex >= layers.length) {
      isStale =
          true; // the source layer itself is gone (deleted, or doc reloaded/undone past it)
    } else {
      final layer = layers[session.sourceLayerIndex];
      final currentFile = layer.images.isEmpty ? '' : layer.images.first.file;
      final dims = imageDimensions(document, session.sourceLayerIndex, 0);
      isStale =
          currentFile != session.sourceFileRef ||
          dims == null ||
          dims.width != session.sourceWidth ||
          dims.height != session.sourceHeight;
    }

    if (isStale != session.stale) {
      session.stale = isStale;
      notifyListeners();
    }
  }

  /// Clears the stale flag without re-running -- the banner's Dismiss action (`02-visual.md`):
  /// the corrector chooses to keep reviewing the existing, disclosed-as-stale regions. Re-baselines
  /// the session's source fingerprint to the layer's *current* state first -- otherwise the next
  /// `refreshCuttingStaleness()` call (fired on the very next rebuild, since it runs on every one)
  /// would immediately compare against the *original* fingerprint again and re-flag the exact same
  /// already-acknowledged change.
  void dismissCuttingStale() {
    final session = cuttingSession;
    final document = coreDoc;
    if (session == null || !session.stale) return;
    if (document != null && session.sourceLayerIndex < doc!.layers.length) {
      final layer = doc!.layers[session.sourceLayerIndex];
      session.sourceFileRef = layer.images.isEmpty
          ? ''
          : layer.images.first.file;
      final dims = imageDimensions(document, session.sourceLayerIndex, 0);
      session.sourceWidth = dims?.width ?? 0;
      session.sourceHeight = dims?.height ?? 0;
    }
    session.stale = false;
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux, Task 3.3: reassigns a pending region's kind before it's accepted
  /// (e.g. the reviewer decides a mis-detected background box is actually a balloon). No-op once
  /// the region has already been accepted or rejected.
  void reclassifyRegion(int regionIndex, String newKind) {
    final pending = cuttingSession?.regions[regionIndex];
    if (pending == null || pending.status != RegionStatus.pending) return;
    pending.region = pending.region.copyWith(kind: newKind);
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux, Task 3.3: adjusts a pending region's bounding box (canvas
  /// resize-handle drag, per `02-visual.md`). No-op once accepted/rejected.
  void adjustRegionBbox(int regionIndex, Rect newBbox) {
    final pending = cuttingSession?.regions[regionIndex];
    if (pending == null || pending.status != RegionStatus.pending) return;
    pending.region = pending.region.copyWith(bbox: newBbox);
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux, Task 3.3: marks a region rejected. `CuttingSession`-only mutation
  /// -- no tile writes, no layer created (03-specifications.md's Data Flow).
  void rejectRegion(int regionIndex) {
    final pending = cuttingSession?.regions[regionIndex];
    if (pending == null || pending.status != RegionStatus.pending) return;
    pending.status = RegionStatus.rejected;
    notifyListeners();
  }

  /// A rejected region can be reconsidered (`02-visual.md`: rejected rows stay visible/clickable)
  /// -- returns it to pending without needing a re-run.
  void unrejectRegion(int regionIndex) {
    final pending = cuttingSession?.regions[regionIndex];
    if (pending == null || pending.status != RegionStatus.rejected) return;
    pending.status = RegionStatus.pending;
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux, Task 3.2: the region-to-layer path. Tile-writes the region's
  /// [DetectedRegion.cropPng] into the document's `tempFolder/layers/` (identical call shape to
  /// [setImageFile]'s tile-write, 03-specifications.md's Data Flow), creates a new [EditorLayer]
  /// with `kind` set from the region, and positions it at `sourceLayer.translate + bbox.topLeft`
  /// (03-specifications.md Finding 4: no size/scale math needed, only a `TranslateAnim`).
  ///
  /// The [EditorLayer] constructor only sets the initial `TranslateAnim.y` (matching today's
  /// `addLayer()`, whose default offsets are vertical-only) -- `.x` is set explicitly afterward
  /// here, since a region's horizontal offset within its source image is never zero in general.
  Future<void> acceptRegion(int regionIndex) async {
    final session = cuttingSession;
    final document = coreDoc;
    final tempFolder = document?.tempFolder;
    if (session == null || document == null || tempFolder == null) return;
    final pending = session.regions[regionIndex];
    if (pending.status != RegionStatus.pending) return;
    final sourceLayer = doc!.layers[session.sourceLayerIndex];

    final position = sourceLayer.translate + pending.region.bbox.topLeft;
    final layersDir = '$tempFolder/layers';
    final stem = sanitizeStem('${pending.region.kind}_region_$regionIndex');
    final tiled = await writeTiles(
      bytes: pending.region.cropPng,
      layersDir: layersDir,
      name: stem,
    );

    _beginHistory();
    final newLayer = EditorLayer(tiled.fileTemplate, at: position)
      ..kind = pending.region.kind;
    newLayer.anims.first.x = position.dx;
    doc!.layers.add(newLayer);
    pending.status = RegionStatus.accepted;
    _commitHistory();
    notifyListeners();
  }

  /// vdd-comics-editor-ai-uiux, Task 3.4: writes a region's crop into
  /// `work/library/<charactersOrEnvironments>/<name>/` -- plain filesystem append, no
  /// re-clustering/embedding logic (03-specifications.md's disclosed simplification). No-op for
  /// kinds the library doesn't have a bucket for (only "character"/"background" -- matches
  /// `build_library.py`'s own `KIND_TO_LIBRARY_DIR`), and if the `comics-multimodal` checkout
  /// isn't found at all.
  Future<bool> insertIntoLibrary(int regionIndex, String name) async {
    final pending = cuttingSession?.regions[regionIndex];
    if (pending == null) return false;
    final kindDir = switch (pending.region.kind) {
      'character' => 'characters',
      'background' => 'environments',
      _ => null,
    };
    if (kindDir == null) return false;
    final libraryRoot = resolveLibraryDir();
    if (libraryRoot == null) return false;

    final targetName = name.trim().isEmpty ? 'unclustered' : name.trim();
    final dir = Directory('$libraryRoot/$kindDir/$targetName');
    await dir.create(recursive: true);
    final fileName =
        'r${regionIndex}_${DateTime.now().microsecondsSinceEpoch}.png';
    await File('${dir.path}/$fileName').writeAsBytes(pending.region.cropPng);
    return true;
  }

  /// vdd-comics-editor-ai-uiux, Task 5.2: inserts an already-clustered library item (character/
  /// environment crop from `work/library/`) as a new layer -- same tile-write + `EditorLayer`
  /// creation path as [acceptRegion], but with no bbox context (nothing was just cut here), so
  /// position uses [addLayer]'s own incremental-offset convention instead of a source-relative
  /// translate.
  Future<bool> insertLibraryItemAsLayer(Uint8List bytes, String kind) async {
    final document = coreDoc;
    final tempFolder = document?.tempFolder;
    if (document == null || tempFolder == null) return false;
    final d = doc!;

    final layersDir = '$tempFolder/layers';
    final stem = sanitizeStem(
      '${kind}_library_${DateTime.now().microsecondsSinceEpoch}',
    );
    final tiled = await writeTiles(
      bytes: bytes,
      layersDir: layersDir,
      name: stem,
    );

    _beginHistory();
    final newLayer = EditorLayer(
      tiled.fileTemplate,
      at: Offset(40, 60.0 + d.layers.length * 30),
    )..kind = kind;
    d.layers.add(newLayer);
    _commitHistory();
    notifyListeners();
    return true;
  }

  // ---------- sounds ----------
  void addSound() {
    _beginHistory();
    final start = currentTime.round();
    doc!.sounds.add(
      EditorSound('sound_${doc!.sounds.length + 1}.mp3')
        ..anims.add(Anim(AnimType.sound, start: start, end: start + 200)),
    );
    _commitHistory();
    selectSound(doc!.sounds.length - 1);
  }

  void moveSound(int dir) {
    if (selKind != SelKind.sound) return;
    final i = selIndex, j = i + dir;
    final ss = doc!.sounds;
    if (j < 0 || j >= ss.length) return;
    _beginHistory();
    final tmp = ss[i];
    ss[i] = ss[j];
    ss[j] = tmp;
    selIndex = j;
    _commitHistory();
    notifyListeners();
  }

  // ---------- animations ----------
  void addAnim(AnimType type) {
    final l = selectedLayer;
    final s = selectedSound;
    if (l == null && s == null) return;
    final start = currentTime.round();
    _beginHistory();
    if (l != null) {
      l.anims.add(Anim(type, start: start, end: start + 200));
      selAnim = l.anims.length - 1;
    } else if (s != null) {
      s.anims.add(Anim(AnimType.sound, start: start, end: start + 200));
      selAnim = s.anims.length - 1;
    }
    _commitHistory();
    notifyListeners();
  }

  void deleteAnim() {
    if (currentAnim == null) return;
    _beginHistory();
    selectedAnims.removeAt(selAnim);
    selAnim = selectedAnims.isEmpty ? -1 : 0;
    _commitHistory();
    notifyListeners();
  }

  void editAnim(void Function(Anim a) fn) {
    final a = currentAnim;
    if (a == null) return;
    _beginHistory();
    fn(a);
    _commitHistory();
    notifyListeners();
  }

  void previewAnim(void Function(Anim a) fn) {
    final animation = currentAnim;
    if (animation == null) return;
    fn(animation);
    notifyListeners();
  }
}

/// Inherited access + rebuild-on-change, no external state package.
class EditorScope extends InheritedNotifier<EditorController> {
  const EditorScope({
    super.key,
    required EditorController controller,
    required super.child,
  }) : super(notifier: controller);

  static EditorController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EditorScope>();
    assert(scope != null, 'EditorScope not found in context');
    return scope!.notifier!;
  }
}

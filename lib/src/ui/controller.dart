import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// v2.9 обвязка: ядро (процесс на десктопе / NativeAOT+FFI на мобильных).
import '../ai/balloon_ai_client.dart';
import '../ai/stub_balloon_ai_client.dart';
import '../bridge/comics_core.dart';
import '../bridge/documents.dart';
import '../bridge/models_mapping.dart';
import '../i18n/language_registry.dart';
import '../io/tile_writer.dart';
import 'edit_history.dart';
import 'models.dart';

/// Which element type is selected in the right-hand Properties pane.
enum SelKind { none, layer, sound }

/// Single source of truth. Every mutation calls notifyListeners();
/// widgets rebuild through EditorScope / ListenableBuilder.
class EditorController extends ChangeNotifier {
  ComicsDoc? doc;
  Lang lang = Lang.en;
  bool muted = false;

  SelKind selKind = SelKind.none;
  int selIndex = -1;
  int selAnim = -1;

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
  Anim? get currentAnim =>
      (selAnim >= 0 && selAnim < selectedAnims.length) ? selectedAnims[selAnim] : null;

  // ---- recent files for the Open dialog ----
  static const recents = <RecentFile>[
    RecentFile('beach.comics', DocType.comics, 'Comics · 1080×1920 · edited today'),
    RecentFile('city.comics', DocType.comics, 'Comics · 1080×1920 · 3 days ago'),
    RecentFile('island.puzzle', DocType.puzzle, 'Puzzle · 1024×768 · last week'),
    RecentFile('maze.puzzle', DocType.puzzle, 'Puzzle · 1024×768 · 2 weeks ago'),
  ];

  // ---------- v2.9: реальные файлы через headless-ядро ----------
  final ComicsCore core = createComicsCore();
  CoreDocument? coreDoc;
  String? coreError;

  bool get coreAvailable => core.isAvailable;

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
    final fileName = document.doc.name.isEmpty ? 'untitled.comics' : document.doc.name;
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
    canvasViewport.dispose();
    core.dispose();
    super.dispose();
  }

  // ---------- document lifecycle ----------
  void newDoc(DocType type) {
    coreDoc = null;
    doc = ComicsDoc(
      name: type == DocType.comics ? 'untitled.comics' : 'untitled.puzzle',
      type: type,
      width: type == DocType.comics ? 1080 : 1024,
      height: type == DocType.comics ? 1920 : 768,
    );
    _history.clear();
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
    resetViewport();
    if (f.name == 'beach.comics') _seedBeach();
    _clearSelection();
    if (doc!.layers.isNotEmpty) selectLayer(doc!.layers.length - 2 < 0 ? 0 : 2);
    notifyListeners();
  }

  /// The sample scene used across the mockups.
  void _seedBeach() {
    final d = doc!;
    d.layers
      ..add(EditorLayer('sky.png', at: const Offset(0, -40))
        ..swatch = const Color(0xFF2C4256)
        ..size = 1.0)
      ..add(EditorLayer('clouds.png', at: const Offset(40, 120))
        ..swatch = const Color(0xFF4E555C)
        ..size = .5)
      ..add(EditorLayer('hero.png', at: const Offset(70, 210))
        ..swatch = const Color(0xFF57422D)
        ..size = .55
        ..anims.add(Anim(AnimType.rotate, start: 210, end: 360)..angle = 45)
        ..anims.add(Anim(AnimType.alpha, start: 360, end: 480)..alpha = .5))
      ..add(EditorLayer('foreground.png', at: const Offset(0, 430))
        ..swatch = const Color(0xFF374A32)
        ..size = 1.0
        ..visible = false);
    d.sounds
      ..add(EditorSound('wind.mp3')..anims.add(Anim(AnimType.sound, start: 140, end: 320)))
      ..add(EditorSound('wave.mp3')..anims.add(Anim(AnimType.sound, start: 420, end: 560)));
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
    bool isBalloonKind(EditorLayer l) => l.kind == 'balloon' || l.kind == 'caption';
    return [for (var i = 0; i < d.layers.length; i++) if (isBalloonKind(d.layers[i])) i];
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
    final currentPos = selKind == SelKind.layer ? indices.indexOf(selIndex) : -1;
    final nextPos = (currentPos == -1 ? 0 : currentPos + direction).clamp(0, indices.length - 1);
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

  void setScale(double s) {
    if (doc == null) return;
    _beginHistory();
    doc?.scale = s;
    _commitHistory();
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
    final l = EditorLayer('layer_${d.layers.length + 1}.png',
        at: Offset(40, 60.0 + d.layers.length * 30))
      ..swatch = Colors.primaries[d.layers.length % Colors.primaries.length].shade700;
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
      doc!.layers.removeAt(selIndex);
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

  /// Drag the selected layer around the canvas (Translate).
  void dragSelected(Offset delta) {
    final l = selectedLayer;
    if (l == null) return;
    l.translate += delta;
    notifyListeners();
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
        bytes: bytes, layersDir: layersDir, name: '${sanitizeStem(layer.name)}_$langCode');

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
        bytes: bytes, layersDir: layersDir, name: '${sanitizeStem(layer.name)}_${langCode}_popup');

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
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false; // отмена — не ошибка
    await setImageFile(langCode, bytes);
    return true;
  }

  /// Same as [pickImageFile] but for `Popup`.
  Future<bool> pickImagePopup(String langCode) async {
    if (selectedLayer == null || coreDoc?.tempFolder == null) return false;
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return false;
    await setImagePopup(langCode, bytes);
    return true;
  }

  // ---------- sounds ----------
  void addSound() {
    _beginHistory();
    doc!.sounds.add(EditorSound('sound_${doc!.sounds.length + 1}.mp3')
      ..anims.add(Anim(AnimType.sound, start: playhead, end: playhead + 200)));
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
    final start = playhead;
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

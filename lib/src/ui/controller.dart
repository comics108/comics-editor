import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// v2.9 обвязка: ядро (процесс на десктопе / NativeAOT+FFI на мобильных).
import '../bridge/comics_core.dart';
import '../bridge/documents.dart';
import '../bridge/models_mapping.dart';
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

  /// Открывает .comics/.puzzle через Comics.Editor.Headless.
  Future<bool> openPath(String path) async {
    try {
      final result =
          await core.call('openComics', {'path': path}) as Map<String, dynamic>;
      coreDoc =
          comicsFromCore(result['comics'] as Map<String, dynamic>, path);
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

  /// Drag the selected layer around the canvas (Translate).
  void dragSelected(Offset delta) {
    final l = selectedLayer;
    if (l == null) return;
    l.translate += delta;
    notifyListeners();
  }

  void setImageFile(int langIndex, String file) {
    _beginHistory();
    selectedLayer?.images[langIndex].file = file;
    _commitHistory();
    notifyListeners();
  }

  void setImagePopup(int langIndex, String popup) {
    _beginHistory();
    selectedLayer?.images[langIndex].popup = popup;
    _commitHistory();
    notifyListeners();
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

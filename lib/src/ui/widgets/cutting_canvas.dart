import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../bridge/models_mapping.dart';
import '../../io/tile_writer.dart';
import '../controller.dart';
import '../theme.dart';
import 'common.dart';
import 'scene_panel.dart' show KindChip;

/// vdd-comics-editor-ai-uiux, Tasks 4.1 + 4.4: the Cutting mode "canvas" pane -- a bespoke,
/// real-pixel widget (03-specifications.md Finding 3: the shared `canvas_view.dart` renders every
/// layer as an opaque placeholder swatch, never real pixels, for any kind; this does not touch
/// that file). Dispatches on `CuttingSession` state: trigger/empty, running, failure, or the
/// results view with region overlays.
///
/// Simplification, disclosed: `02-visual.md`'s high-fidelity reference dims the page outside the
/// selected region with a full vignette (a punched-hole dark overlay); this implementation instead
/// distinguishes the selected region with a solid bright border + handles against other regions
/// shown at reduced opacity -- materially simpler to implement correctly, and satisfies the same
/// underlying acceptance goal ("the active region is unambiguous") without a custom clip-path
/// painter. Revisit only if a reviewer finds the simplified version genuinely ambiguous in
/// practice.
class CuttingCanvas extends StatelessWidget {
  const CuttingCanvas({
    super.key,
    required this.controller,
    required this.selectedRegionIndex,
    required this.onSelectRegion,
  });

  final EditorController controller;
  final int? selectedRegionIndex;
  final ValueChanged<int> onSelectRegion;

  @override
  Widget build(BuildContext context) {
    final session = controller.cuttingSession;
    if (session == null) return _TriggerScreen(controller: controller);
    if (session.hasFailed) return _FailureScreen(controller: controller, session: session);
    if (session.isRunning) return _RunningScreen(session: session);
    return _ResultsCanvas(
      controller: controller,
      session: session,
      selectedRegionIndex: selectedRegionIndex,
      onSelectRegion: onSelectRegion,
    );
  }
}

/// Reads a layer's real artwork bytes (stitched from its on-disk tiles), for use as a
/// Cutting-mode source image -- shared by the trigger screen (selected layer) and the stale
/// banner's Re-run action (a specific, possibly-not-currently-selected `sourceLayerIndex`).
/// Returns null if there's no backing tempFolder or the layer has no real (tiled) artwork yet --
/// callers treat all of these as "nothing to cut yet", not an error.
Future<Uint8List?> _stitchLayerBytes(EditorController controller, int layerIndex) async {
  final document = controller.coreDoc;
  final tempFolder = document?.tempFolder;
  final layers = controller.doc?.layers;
  if (document == null || tempFolder == null || layers == null || layerIndex >= layers.length) {
    return null;
  }
  final layer = layers[layerIndex];
  if (layer.images.isEmpty) return null;
  final image = layer.images.first;
  if (image.file.isEmpty || !image.file.contains('{0}')) return null;
  final dims = imageDimensions(document, layerIndex, 0);
  if (dims == null) return null;
  return stitchImage(
    layersDir: '${document.tempFolder}/layers',
    fileTemplate: image.file,
    width: dims.width,
    height: dims.height,
  );
}

/// Reads the currently-selected Edit-mode layer's real artwork bytes -- the trigger screen's own
/// convenience wrapper around [_stitchLayerBytes].
Future<Uint8List?> _sourceBytesForSelectedLayer(EditorController controller) async {
  final layer = controller.selectedLayer;
  if (layer == null) return null;
  final layerIndex = controller.doc!.layers.indexOf(layer);
  return _stitchLayerBytes(controller, layerIndex);
}

class _TriggerScreen extends StatefulWidget {
  const _TriggerScreen({required this.controller});
  final EditorController controller;

  @override
  State<_TriggerScreen> createState() => _TriggerScreenState();
}

class _TriggerScreenState extends State<_TriggerScreen> {
  bool _starting = false;
  String? _pickError;

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _pickError = null;
    });
    final layer = widget.controller.selectedLayer;
    final layerIndex = layer == null ? -1 : widget.controller.doc!.layers.indexOf(layer);
    final bytes = await _sourceBytesForSelectedLayer(widget.controller);
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _starting = false;
        _pickError = 'Select a layer with real artwork first, then Set as source.';
      });
      return;
    }
    widget.controller.triggerCutting(bytes, layerIndex);
    setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.controller.selectedLayer;
    return PanelCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_cut, size: 32, color: Hs.textTertiary),
              const SizedBox(height: 12),
              Text(
                layer == null
                    ? 'Select a layer in Edit mode to use as the Cutting source.'
                    : 'Source: ${layer.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Hs.textBody),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rectification (perspective correction) is not done here — '
                'import an already-cropped page image.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Hs.textSecondary),
              ),
              const SizedBox(height: 16),
              HsButton(
                _starting ? 'Starting…' : 'Cut / Segment',
                icon: Icons.content_cut,
                onTap: (layer == null || _starting) ? null : _start,
              ),
              if (_pickError != null) ...[
                const SizedBox(height: 10),
                Text(_pickError!,
                    style: const TextStyle(fontSize: 12, color: Hs.coral500),
                    textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningScreen extends StatelessWidget {
  const _RunningScreen({required this.session});
  final CuttingSession session;

  static const _stageLabels = {
    'loading_model': 'Loading model…',
    'segmenting': 'Segmenting page…',
    'extracting_regions': 'Extracting regions…',
  };

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                  width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 16),
              Text(_stageLabels[session.stage] ?? 'Running…',
                  style: const TextStyle(fontSize: 14, color: Hs.textBody)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Hs.blue500, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration:
                          const BoxDecoration(shape: BoxShape.circle, color: Hs.blue500),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Local process', style: TextStyle(fontSize: 12, color: Hs.textSecondary)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureScreen extends StatelessWidget {
  const _FailureScreen({required this.controller, required this.session});
  final EditorController controller;
  final CuttingSession session;

  static const _messages = {
    'python_not_found': "Cutting pipeline not found on this machine.",
    'model_checkpoint_not_found':
        'The segmentation model has never been trained in this checkout.',
    'image_not_readable': "Couldn't read the source image.",
    'process_error': 'The local pipeline process failed unexpectedly.',
  };

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Hs.coral500, size: 28),
              const SizedBox(height: 12),
              Text('Cutting failed.',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(_messages[session.failureReason] ?? session.failureReason ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Hs.textSecondary)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (session.failureRetryable)
                  HsButton(
                    'Retry',
                    onTap: () async {
                      final bytes = session.sourceImageBytes;
                      controller.triggerCutting(bytes, session.sourceLayerIndex);
                    },
                  ),
                const SizedBox(width: 8),
                HsButton('Dismiss', variant: HsVariant.secondary, onTap: controller.cancelCutting),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsCanvas extends StatefulWidget {
  const _ResultsCanvas({
    required this.controller,
    required this.session,
    required this.selectedRegionIndex,
    required this.onSelectRegion,
  });

  final EditorController controller;
  final CuttingSession session;
  final int? selectedRegionIndex;
  final ValueChanged<int> onSelectRegion;

  @override
  State<_ResultsCanvas> createState() => _ResultsCanvasState();
}

// vdd-comics-editor-ai-uiux (follow-up): zoom control, mirroring canvas_view.dart's
// _ZoomControl/EditorController.zoomBy exactly, but against a local TransformationController --
// this canvas is a bespoke widget, not the shared Edit-mode canvas, so it doesn't share
// EditorController.canvasViewport (that field is specifically for the Edit-mode _Stage).
// panEnabled without scaleEnabled (pinch/trackpad zoom is intentionally off, in favor of the
// explicit +/- buttons) mirrors the exact same "drag gesture nested inside InteractiveViewer"
// shape canvas_view.dart's own layer-drag already uses successfully in this codebase.
const _kZoomMin = 0.25;
const _kZoomMax = 4.0;
const _kZoomStep = 1.25;

class _ResultsCanvasState extends State<_ResultsCanvas> {
  img.Image? _decoded;
  CuttingSession? _decodedFor;

  final TransformationController _zoomController = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _decode();
    _scheduleStalenessCheck();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  void _bumpZoom(double factor) {
    final viewportBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final focal = viewportBox != null ? viewportBox.size.center(Offset.zero) : Offset.zero;
    final current = _zoomController.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(_kZoomMin, _kZoomMax);
    final scaleDelta = target / current;
    if (scaleDelta == 1.0) return;
    final scenePoint = _zoomController.toScene(focal);
    _zoomController.value = _zoomController.value.clone()
      ..translateByDouble(scenePoint.dx, scenePoint.dy, 0, 1)
      ..scaleByDouble(scaleDelta, scaleDelta, scaleDelta, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);
  }

  @override
  void didUpdateWidget(covariant _ResultsCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) _decode();
    // Runs on every rebuild this widget participates in (the app rebuilds everything via one
    // root AnimatedBuilder, per editor_screen.dart) -- deferred to a post-frame callback since
    // this can call notifyListeners(), and didUpdateWidget runs mid-build.
    _scheduleStalenessCheck();
  }

  void _scheduleStalenessCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.refreshCuttingStaleness();
    });
  }

  void _decode() {
    final session = widget.session;
    final decoded = img.decodeImage(session.sourceImageBytes);
    setState(() {
      _decoded = decoded;
      _decodedFor = session;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decoded;
    if (!identical(_decodedFor, widget.session) || decoded == null) {
      return const PanelCard(child: Center(child: CircularProgressIndicator()));
    }

    return PanelCard(
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            color: Hs.surfaceCloud,
            child: LayoutBuilder(builder: (context, box) {
              final fitScale = (box.maxWidth / decoded.width)
                  .clamp(0, box.maxHeight / decoded.height)
                  .toDouble();
              final w = decoded.width * fitScale;
              final h = decoded.height * fitScale;
              return InteractiveViewer(
                key: _viewportKey,
                transformationController: _zoomController,
                minScale: _kZoomMin,
                maxScale: _kZoomMax,
                panEnabled: true,
                scaleEnabled: false,
                boundaryMargin: const EdgeInsets.all(200),
                trackpadScrollCausesScale: false,
                child: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: Image.memory(widget.session.sourceImageBytes, fit: BoxFit.fill),
                      ),
                      for (var i = 0; i < widget.session.regions.length; i++)
                        if (widget.session.regions[i].status != RegionStatus.rejected)
                          _RegionOverlay(
                            controller: widget.controller,
                            regionIndex: i,
                            pending: widget.session.regions[i],
                            scale: fitScale,
                            selected: widget.selectedRegionIndex == i,
                            onTap: () => widget.onSelectRegion(i),
                          ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
        Positioned(left: 14, bottom: 14, child: _CuttingZoomControl(zoomController: _zoomController, onBump: _bumpZoom)),
        Positioned(
          right: 14,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Hs.white,
              borderRadius: BorderRadius.circular(Hs.rBtn),
              boxShadow: Hs.cardShadow,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: Hs.blue500, width: 2)),
                child: Center(
                  child: Container(
                      width: 6,
                      height: 6,
                      decoration:
                          const BoxDecoration(shape: BoxShape.circle, color: Hs.blue500)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Local process', style: TextStyle(fontSize: 13, color: Hs.textSecondary)),
            ]),
          ),
        ),
        if (widget.session.stale)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _StaleBanner(controller: widget.controller, session: widget.session),
          ),
      ]),
    );
  }
}

/// vdd-comics-editor-ai-uiux: the "source image changed after regions were generated" banner --
/// Requirements' stale-output edge case, mirroring `BalloonEditorCard`'s own stale-indicator
/// pattern (never silently invalidate or silently keep showing outdated results without saying
/// so). Re-run re-stitches the *current* source layer and starts a fresh session; Dismiss just
/// clears the flag and keeps reviewing the (disclosed-as-stale) existing regions.
class _StaleBanner extends StatefulWidget {
  const _StaleBanner({required this.controller, required this.session});
  final EditorController controller;
  final CuttingSession session;

  @override
  State<_StaleBanner> createState() => _StaleBannerState();
}

class _StaleBannerState extends State<_StaleBanner> {
  bool _rerunning = false;

  Future<void> _rerun() async {
    setState(() => _rerunning = true);
    final bytes = await _stitchLayerBytes(widget.controller, widget.session.sourceLayerIndex);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _rerunning = false);
      return;
    }
    widget.controller.triggerCutting(bytes, widget.session.sourceLayerIndex);
  }

  void _dismiss() => widget.controller.dismissCuttingStale();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFDE4DC),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: Hs.coral500),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Source image changed since these regions were generated. Re-run cutting to '
            'refresh, or continue reviewing stale results.',
            style: TextStyle(fontSize: 12, color: Hs.textBody),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _rerunning ? null : _rerun,
          child: Text(_rerunning ? 'Re-running…' : 'Re-run'),
        ),
        TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
      ]),
    );
  }
}

/// vdd-comics-editor-ai-uiux (follow-up): zoom control for the results canvas, mirroring
/// `canvas_view.dart`'s `_ZoomControl` (same layout/styling), but driving a local
/// `TransformationController` via [onBump] instead of `EditorController.zoomBy` (which is
/// specifically scoped to the Edit-mode canvas's own viewport).
class _CuttingZoomControl extends StatelessWidget {
  const _CuttingZoomControl({required this.zoomController, required this.onBump});
  final TransformationController zoomController;
  final ValueChanged<double> onBump;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: zoomController,
      builder: (context, _) {
        final pct = (zoomController.value.getMaxScaleOnAxis() * 100).round();
        return Container(
          decoration: BoxDecoration(
            color: Hs.white,
            borderRadius: BorderRadius.circular(Hs.rBtn),
            boxShadow: Hs.cardShadow,
          ),
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _zoomBtn('−', () => onBump(1 / _kZoomStep)),
            SizedBox(
                width: 50,
                child: Text('$pct%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _zoomBtn('+', () => onBump(_kZoomStep)),
            Container(
                width: 1,
                height: 20,
                color: Hs.divider,
                margin: const EdgeInsets.symmetric(horizontal: 2)),
            IconButton(
              onPressed: () => zoomController.value = Matrix4.identity(),
              icon: const Icon(Icons.crop_free, size: 18, color: Hs.textSecondary),
              tooltip: 'Fit',
              visualDensity: VisualDensity.compact,
            ),
          ]),
        );
      },
    );
  }

  Widget _zoomBtn(String t, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
              child: Text(t, style: const TextStyle(fontSize: 18, color: Hs.textBody))),
        ),
      );
}

/// One region's on-canvas box: unselected regions are a thin, low-opacity outline in their kind's
/// color (tap to select); the selected region gets a solid border plus 8 drag handles wired to
/// [EditorController.adjustRegionBbox].
class _RegionOverlay extends StatelessWidget {
  const _RegionOverlay({
    required this.controller,
    required this.regionIndex,
    required this.pending,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final EditorController controller;
  final int regionIndex;
  final PendingRegion pending;
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bbox = pending.region.bbox;
    final (_, color, _) = KindChip.styleFor(pending.region.kind);
    final left = bbox.left * scale;
    final top = bbox.top * scale;
    final width = bbox.width * scale;
    final height = bbox.height * scale;
    final accepted = pending.status == RegionStatus.accepted;

    Widget box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : color.withValues(alpha: .8),
            width: selected ? 2.5 : 2,
          ),
          color: accepted ? color.withValues(alpha: .08) : null,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: color,
            child: Text('#${regionIndex + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
    if (!selected) {
      box = Opacity(opacity: .8, child: box);
    }

    return Positioned(
      left: left,
      top: top,
      child: selected && pending.status == RegionStatus.pending
          ? _ResizableHandles(
              width: width,
              height: height,
              color: color,
              onResize: (dl, dt, dr, db) {
                final newBbox = Rect.fromLTRB(
                  bbox.left + dl / scale,
                  bbox.top + dt / scale,
                  bbox.right + dr / scale,
                  bbox.bottom + db / scale,
                );
                controller.adjustRegionBbox(regionIndex, newBbox);
              },
              child: box,
            )
          : box,
    );
  }
}

/// Eight drag handles (4 corners + 4 edge midpoints), each reporting how much to move the
/// left/top/right/bottom edges via [onResize] -- mirrors `canvas_view.dart`'s `_WithHandles` dot
/// styling, extended here to actually resize (that one only decorates a fixed-size swatch).
class _ResizableHandles extends StatelessWidget {
  const _ResizableHandles({
    required this.width,
    required this.height,
    required this.color,
    required this.onResize,
    required this.child,
  });

  final double width;
  final double height;
  final Color color;
  final void Function(double dl, double dt, double dr, double db) onResize;
  final Widget child;

  static const _s = 10.0;

  Widget _dot() => Container(
        width: _s,
        height: _s,
        decoration: BoxDecoration(
          color: Hs.white,
          border: Border.all(color: Hs.blue500, width: 1.5),
        ),
      );

  Widget _handle({
    required double left,
    required double top,
    required bool moveLeft,
    required bool moveTop,
    required bool moveRight,
    required bool moveBottom,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onResize(
          moveLeft ? d.delta.dx : 0,
          moveTop ? d.delta.dy : 0,
          moveRight ? d.delta.dx : 0,
          moveBottom ? d.delta.dy : 0,
        ),
        child: _dot(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(clipBehavior: Clip.none, children: [
        child,
        _handle(left: -_s / 2, top: -_s / 2, moveLeft: true, moveTop: true, moveRight: false, moveBottom: false),
        _handle(left: width - _s / 2, top: -_s / 2, moveLeft: false, moveTop: true, moveRight: true, moveBottom: false),
        _handle(left: -_s / 2, top: height - _s / 2, moveLeft: true, moveTop: false, moveRight: false, moveBottom: true),
        _handle(left: width - _s / 2, top: height - _s / 2, moveLeft: false, moveTop: false, moveRight: true, moveBottom: true),
        _handle(left: width / 2 - _s / 2, top: -_s / 2, moveLeft: false, moveTop: true, moveRight: false, moveBottom: false),
        _handle(left: width / 2 - _s / 2, top: height - _s / 2, moveLeft: false, moveTop: false, moveRight: false, moveBottom: true),
        _handle(left: -_s / 2, top: height / 2 - _s / 2, moveLeft: true, moveTop: false, moveRight: false, moveBottom: false),
        _handle(left: width - _s / 2, top: height / 2 - _s / 2, moveLeft: false, moveTop: false, moveRight: true, moveBottom: false),
      ]),
    );
  }
}

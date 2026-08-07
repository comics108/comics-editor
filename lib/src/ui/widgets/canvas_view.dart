import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../anim/keyframe_interpolator.dart';
import '../controller.dart';
import '../theme.dart';
import 'common.dart';

/// The center stage. Renders the page (comics strip or puzzle board), lets you
/// drag the selected layer (Translate), draws selection handles, and hosts the
/// zoom control (puzzle Scale slider / comics fit) + Preview toggle.
class CanvasView extends StatelessWidget {
  const CanvasView({super.key, this.showPreviewToggle = true});
  final bool showPreviewToggle;

  @override
  Widget build(BuildContext context) {
    final c = EditorScope.of(context);
    return PanelCard(
      child: Stack(
        children: [
          Positioned.fill(child: _Stage(c)),
          Positioned(left: 14, bottom: 14, child: _ZoomControl(c)),
          if (showPreviewToggle)
            Positioned(right: 14, bottom: 14, child: _PreviewToggle(c)),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage(this.c);
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    final aspect = doc.width / doc.height;
    return Container(
      color: Hs.surfaceCloud,
      child: LayoutBuilder(builder: (context, box) {
        final maxH = box.maxHeight - 40;
        final maxW = box.maxWidth - 40;
        double pageW, pageH;
        if (c.isPuzzle) {
          // Puzzle boards are bounded, not a tall scrolling strip -- keep the
          // existing fit-whole-board-then-zoom-slider behavior unchanged.
          pageH = maxH;
          pageW = pageH * aspect;
          if (pageW > maxW) {
            pageW = maxW;
            pageH = pageW / aspect;
          }
          pageW *= doc.scale;
          pageH *= doc.scale;
        } else {
          // vdd-comics-editor-vertical-scroll, Task 3.1: fit-width, real
          // proportional height -- for a real (much taller than wide)
          // document this makes pageH far exceed the viewport, which is the
          // point: InteractiveViewer's existing pan now has real vertical
          // distance to scroll through, one responsive-sized "screenful" at
          // a time, matching legacy's ScrollViewer scrolling through a
          // full-height Grid (see 01-requirements.md, Major Finding point
          // 2) -- responsive per Anton's decision, not v2.8's hardcoded
          // ratio=1.4. Previously this fit the WHOLE document into maxH,
          // shrinking it to be fully visible at once (Requirements Gap 2).
          pageW = maxW;
          pageH = pageW / aspect;
        }
        return InteractiveViewer(
          key: c.viewportKey,
          transformationController: c.canvasViewport,
          minScale: EditorController.kCanvasZoomMin,
          maxScale: EditorController.kCanvasZoomMax,
          boundaryMargin: const EdgeInsets.all(200),
          trackpadScrollCausesScale: false,
          // vdd-comics-editor-vertical-scroll, Task 3.2: `constrained` (default
          // true) forces the child to size itself to the viewport, silently
          // clamping panning to boundaryMargin regardless of the child's real
          // size -- documented explicitly in InteractiveViewer's own source as
          // wrong for "a child bigger than the viewport that can be panned to
          // reveal parts that were initially offscreen," exactly our case since
          // Task 3.1. The child is already explicitly sized via SizedBox below
          // for both branches above, satisfying `constrained: false`'s
          // requirement that "the child is sized properly."
          constrained: false,
          child: Center(
            child: SizedBox(
              width: pageW,
              height: pageH,
              child: _Page(c, Size(pageW, pageH)),
            ),
          ),
        );
      }),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page(this.c, this.size);
  final EditorController c;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    // page-space uses the design width as reference; scale positions to px
    final k = size.width / doc.width;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1114),
        boxShadow: [
          BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 10))
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            for (var i = 0; i < doc.layers.length; i++)
              _LayerItem(c, i, k),
          ],
        ),
      ),
    );
  }
}

class _LayerItem extends StatelessWidget {
  const _LayerItem(this.c, this.i, this.k);
  final EditorController c;
  final int i;
  final double k; // page-units -> px
  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    final l = doc.layers[i];
    if (!l.visible) return const SizedBox.shrink();
    final selected = c.selKind == SelKind.layer && c.selIndex == i;

    final w = doc.width * l.size * k;
    final h = w * 1.3;

    Widget swatch = SizedBox(
      width: w,
      height: h,
      child: Stack(children: [
        Positioned.fill(child: HatchSwatch(l.swatch, size: w, radius: 0)),
        Positioned(
          left: 8,
          top: 8,
          child: Text(l.name,
              style: TextStyle(
                  fontFamily: Hs.serifData.first,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: .75))),
        ),
        if (selected)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Hs.blue500, width: 1.5)),
            ),
          ),
      ]),
    );

    // vdd-comics-editor-vertical-scroll, Task 2.4: interpolated transform,
    // ported from legacy/comics-editor-v2.8's Anim.cs (see
    // KeyframeInterpolator). Wrapped in an AnimatedBuilder listening to
    // c.canvasViewport specifically -- panning updates that TransformationController
    // directly, not EditorController itself, so this widget wouldn't otherwise
    // rebuild as currentTime changes (EditorScope only rebuilds on
    // EditorController.notifyListeners()).
    //
    // tdd-dot-comics-format Plan Task 5.4: KeyframeInterpolator now also
    // accepts a wallClockMs parameter for time-basis anims (Anim.basis) --
    // not wired to a live clock here. A live-ticking source was attempted
    // and reverted (see EditorController's own note on this) after it broke
    // the test suite's no-pending-timer invariant; a time-basis anim is
    // real, tested, and correctly composed, but will render "frozen" at
    // wallClockMs=0 in the actual running app until a lifecycle-safe live
    // clock is wired in as a follow-up.
    return AnimatedBuilder(
      animation: c.canvasViewport,
      builder: (context, _) {
        final t = c.currentTime;
        final translate = KeyframeInterpolator.translateAt(l.anims, t, l.translate);
        final (scaleX, scaleY, sPivotX, sPivotY) = KeyframeInterpolator.scaleAt(l.anims, t);
        final (angle, rPivotX, rPivotY) = KeyframeInterpolator.rotateAt(l.anims, t);
        final alpha = KeyframeInterpolator.alphaAt(l.anims, t);

        // Composition order matches legacy's LayersControl.xaml: rotate is
        // the outer transform (pivot = Rotate.Pivot), scale is applied
        // inside it (pivot = Scale.Pivot) -- Angle is in degrees, as in WPF.
        Widget transformed = Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          alignment: Alignment(sPivotX * 2 - 1, sPivotY * 2 - 1),
          child: swatch,
        );
        transformed = Transform.rotate(
          angle: angle * math.pi / 180,
          alignment: Alignment(rPivotX * 2 - 1, rPivotY * 2 - 1),
          child: transformed,
        );
        transformed = Opacity(opacity: alpha.clamp(0.0, 1.0), child: transformed);

        return Positioned(
          left: translate.dx * k,
          top: translate.dy * k,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.selectLayer(i),
            onPanStart: (_) {
              c.selectLayer(i);
              c.beginGestureHistory();
            },
            onPanUpdate: (d) {
              final vz = c.canvasViewport.value.getMaxScaleOnAxis();
              c.dragSelected(Offset(d.delta.dx / (k * vz), d.delta.dy / (k * vz)));
            },
            onPanEnd: (_) => c.commitGestureHistory(),
            child: selected ? _WithHandles(child: transformed) : transformed,
          ),
        );
      },
    );
  }
}

/// 8 resize squares + a rotate stem — matches the WPF Scale/Rotate handles.
class _WithHandles extends StatelessWidget {
  const _WithHandles({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const s = 10.0;
    Widget dot() => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: Hs.white,
            border: Border.all(color: Hs.blue500, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(left: -s / 2, top: -s / 2, child: dot()),
      Positioned(right: -s / 2, top: -s / 2, child: dot()),
      Positioned(left: -s / 2, bottom: -s / 2, child: dot()),
      Positioned(right: -s / 2, bottom: -s / 2, child: dot()),
      Positioned(left: 0, right: 0, top: -s / 2, child: Center(child: dot())),
      Positioned(left: 0, right: 0, bottom: -s / 2, child: Center(child: dot())),
      Positioned(top: 0, bottom: 0, left: -s / 2, child: Center(child: dot())),
      Positioned(top: 0, bottom: 0, right: -s / 2, child: Center(child: dot())),
      // rotate stem
      Positioned(
        left: 0,
        right: 0,
        top: -34,
        child: Center(
          child: Column(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Hs.white,
                shape: BoxShape.circle,
                border: Border.all(color: Hs.blue500, width: 1.5),
              ),
            ),
            Container(width: 2, height: 22, color: Hs.blue500),
          ]),
        ),
      ),
    ]);
  }
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c.canvasViewport,
      builder: (context, _) {
        final pct = (c.canvasViewport.value.getMaxScaleOnAxis() * 100).round();
        return Container(
          decoration: BoxDecoration(
            color: Hs.white,
            borderRadius: BorderRadius.circular(Hs.rBtn),
            boxShadow: Hs.cardShadow,
          ),
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _zoomBtn('−', () => _bump(c, 1 / EditorController.kCanvasZoomStep)),
            SizedBox(
                width: 50,
                child: Text('$pct%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _zoomBtn('+', () => _bump(c, EditorController.kCanvasZoomStep)),
            Container(width: 1, height: 20, color: Hs.divider, margin: const EdgeInsets.symmetric(horizontal: 2)),
            IconButton(
              onPressed: c.resetViewport,
              icon: const Icon(Icons.crop_free, size: 18, color: Hs.textSecondary),
              tooltip: 'Fit',
              visualDensity: VisualDensity.compact,
            ),
          ]),
        );
      },
    );
  }

  void _bump(EditorController c, double factor) {
    final viewportBox =
        c.viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final focal = viewportBox != null
        ? viewportBox.size.center(Offset.zero)
        : Offset.zero;
    c.zoomBy(factor, focal);
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

class _PreviewToggle extends StatelessWidget {
  const _PreviewToggle(this.c);
  final EditorController c;
  @override
  Widget build(BuildContext context) {
    final on = c.selectedLayer?.preview ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Hs.white,
        borderRadius: BorderRadius.circular(Hs.rBtn),
        boxShadow: Hs.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('Preview', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        HsToggle(
            value: on,
            onTap: c.selectedLayer == null ? () {} : c.togglePreview),
      ]),
    );
  }
}

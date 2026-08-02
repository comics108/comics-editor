// vdd-comics-editor-vertical-scroll, Task 2.3: `currentTime` replaces `playhead`
// as the source addAnim/addSound stamp new keyframes from. `playhead` itself is
// deliberately left untouched (timeline.dart still reads/drives it) -- see the
// doc comment on EditorController.currentTime for why.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';

EditorController _controllerWithLayer() {
  final c = EditorController()
    ..doc = (ComicsDoc(name: 'test', type: DocType.comics)
      ..layers.add(EditorLayer('layer1')));
  c.selectLayer(0);
  return c;
}

void main() {
  test('currentTime is 0 at the identity transform (top of document)', () {
    final c = _controllerWithLayer();
    expect(c.currentTime, 0);
  });

  test('currentTime increases as the canvas pans down (content moves up on screen)', () {
    final c = _controllerWithLayer();
    // Simulate panning down: content shifts up on screen -> negative Y translation.
    c.canvasViewport.value = Matrix4.identity()..translateByDouble(0, -500, 0, 1);
    expect(c.currentTime, closeTo(500, 1e-9));
  });

  test('currentTime is invariant to zoom for the same underlying pan', () {
    final c = _controllerWithLayer();
    c.canvasViewport.value = Matrix4.identity()
      ..translateByDouble(0, -500, 0, 1)
      ..scaleByDouble(2, 2, 2, 1);
    // At 2x zoom, a screen-space translation of -500 corresponds to half the
    // document-space distance a 1x zoom would -- currentTime should read the
    // real document-space value, not the raw screen-space one.
    expect(c.currentTime, closeTo(250, 1e-9));
  });

  test('addAnim stamps start/end from currentTime, not the unrelated playhead', () {
    final c = _controllerWithLayer();
    c.playhead = 999; // deliberately different, to prove it's not the source anymore
    c.canvasViewport.value = Matrix4.identity()..translateByDouble(0, -4800, 0, 1);

    c.addAnim(AnimType.rotate);

    final anim = c.selectedLayer!.anims.last;
    expect(anim.type, AnimType.rotate);
    expect(anim.start, 4800);
    expect(anim.end, 5000);
    expect(c.playhead, 999); // untouched
  });

  test('addSound stamps start/end from currentTime, not playhead', () {
    final c = _controllerWithLayer();
    c.playhead = 42;
    c.canvasViewport.value = Matrix4.identity()..translateByDouble(0, -1000, 0, 1);

    c.addSound();

    final anim = c.doc!.sounds.single.anims.single;
    expect(anim.start, 1000);
    expect(anim.end, 1200);
    expect(c.playhead, 42); // untouched
  });
}

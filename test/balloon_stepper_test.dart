// vdd-comics-editor-uiux-lettering, Task 5.6: EditorController.stepBalloon/
// balloonStepInfo -- the controller-level logic backing the shared
// [<] N/M [>] stepper across all three platform Lettering layouts. Plain
// unit tests (no widget pumping needed).
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';

void main() {
  test('balloonStepInfo is null with no document, no balloons, or nothing selected', () {
    final controller = EditorController();
    expect(controller.balloonStepInfo(), isNull); // no document

    controller.newDoc(DocType.comics);
    controller.addLayer(); // default kind == null, not a balloon
    expect(controller.balloonStepInfo(), isNull); // no balloon layers

    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    expect(controller.balloonStepInfo(), isNull); // selection is the non-balloon layer
  });

  test('balloonStepInfo reports 1-based position/total among balloon/caption layers only', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')); // excluded
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('hero.png')..kind = 'character'); // excluded
    controller.doc!.layers.add(EditorLayer('c1.png')..kind = 'caption');

    controller.selectLayer(1); // the balloon
    expect(controller.balloonStepInfo(), (position: 1, total: 2));

    controller.selectLayer(3); // the caption
    expect(controller.balloonStepInfo(), (position: 2, total: 2));

    controller.selectLayer(0); // the non-balloon layer
    expect(controller.balloonStepInfo(), isNull);
  });

  test('stepBalloon moves forward/back through balloon/caption layers, skipping others', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('sky.png')); // not a balloon -- must be skipped
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');
    controller.selectLayer(0);

    controller.stepBalloon(1);
    expect(controller.selIndex, 2); // skipped index 1 (non-balloon)
    expect(controller.balloonStepInfo(), (position: 2, total: 2));

    controller.stepBalloon(-1);
    expect(controller.selIndex, 0);
    expect(controller.balloonStepInfo(), (position: 1, total: 2));
  });

  test('stepBalloon clamps at the ends -- no wraparound', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');
    controller.selectLayer(1); // last balloon

    controller.stepBalloon(1); // already at the end
    expect(controller.selIndex, 1);

    controller.stepBalloon(-1);
    expect(controller.selIndex, 0);
    controller.stepBalloon(-1); // already at the start
    expect(controller.selIndex, 0);
  });

  test('stepBalloon starts from the first balloon if nothing balloon-like is selected', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png'));
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.selectLayer(0); // the non-balloon layer

    controller.stepBalloon(1);
    expect(controller.selIndex, 1);
    expect(controller.balloonStepInfo(), (position: 1, total: 1));
  });

  test('stepBalloon is a no-op with zero balloon/caption layers in the document', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    final before = controller.selIndex;

    controller.stepBalloon(1);
    expect(controller.selIndex, before);
    expect(controller.balloonStepInfo(), isNull);
  });
}

// vdd-comics-editor-vertical-scroll, Task 2.4: _LayerItem renders the
// KeyframeInterpolator's computed transform instead of the static
// EditorLayer.translate, and rebuilds as canvasViewport (currentTime) changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/canvas_view.dart';

EditorController _controllerWithAnimatedLayer() {
  final layer = EditorLayer('layer1', at: const Offset(0, 0));
  // Real authoring shape: a seed anim (Start=End=0) plus a translate range.
  layer.anims.clear();
  layer.anims.add(Anim(AnimType.translate, start: 0, end: 0)..y = 100);
  layer.anims.add(Anim(AnimType.translate, start: 4800, end: 5000)
    ..x = 300
    ..y = 300);
  final c = EditorController()
    ..doc = (ComicsDoc(name: 'test', type: DocType.comics, width: 1080, height: 33000)
      ..layers.add(layer));
  return c;
}

Future<void> _pump(WidgetTester tester, EditorController c) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: EditorScope(
        controller: c,
        child: const SizedBox(width: 800, height: 600, child: CanvasView()),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('layer renders at its held position before the anim range starts',
      (tester) async {
    final c = _controllerWithAnimatedLayer();
    await _pump(tester, c);

    // find.byType(Positioned).first is CanvasView's own `Positioned.fill(child:
    // _Stage(c))` -- the layer's own Positioned is the next one built (DFS order).
    final positioned = tester.widget<Positioned>(find.byType(Positioned).at(1));
    // currentTime=0 -> holds the seed anim's value (x=0, y=100), scaled by k.
    expect(positioned.left, closeTo(0, 0.01));
    expect(positioned.top, greaterThan(0));
  });

  testWidgets('panning the canvas moves the layer per the interpolated keyframe',
      (tester) async {
    final c = _controllerWithAnimatedLayer();
    await _pump(tester, c);

    final beforeTop = tester.widget<Positioned>(find.byType(Positioned).at(1)).top;

    // Pan so currentTime lands past the anim's end (5000) -- holds (300, 300).
    c.canvasViewport.value = Matrix4.identity()..translateByDouble(0, -6000, 0, 1);
    await tester.pump();

    final after = tester.widget<Positioned>(find.byType(Positioned).at(1));
    expect(after.top, isNot(closeTo(beforeTop!, 0.01)));
    expect(after.left, greaterThan(0)); // x moved from 0 to 300
  });
}

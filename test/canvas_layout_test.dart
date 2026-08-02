// vdd-comics-editor-vertical-scroll, Task 3.1: comics documents now fit-width
// (real proportional height, taller than the viewport for a real document)
// instead of fit-whole-document (shrunk to fully fit, Requirements Gap 2).
// Puzzle boards are explicitly unaffected -- verified via each layout's
// distinct `k` (page-units -> px scale), read back through a static (no-anim)
// layer's rendered position, since `_Page`/`k` themselves are private to
// canvas_view.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/canvas_view.dart';

Future<Positioned> _pumpAndFindLayer(WidgetTester tester, EditorController c) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: EditorScope(
        controller: c,
        child: const SizedBox(width: 800, height: 600, child: CanvasView()),
      ),
    ),
  ));
  await tester.pump();
  // index 1: CanvasView's own Positioned.fill(child: _Stage) is index 0.
  return tester.widget<Positioned>(find.byType(Positioned).at(1));
}

void main() {
  testWidgets('comics doc: fit-width, not fit-whole-document', (tester) async {
    // A real-shaped tall document (1080 wide, 33000 tall).
    final layer = EditorLayer('layer1', at: const Offset(100, 100));
    final c = EditorController()
      ..doc = (ComicsDoc(name: 'test', type: DocType.comics, width: 1080, height: 33000)
        ..layers.add(layer));

    final positioned = await _pumpAndFindLayer(tester, c);

    // EditorLayer's constructor auto-seeds a translate anim tracking only Y
    // (X stays 0, matching legacy's Layer.Create) -- so `top` (from Y=100)
    // is what reflects `k`, not `left` (X is 0 regardless of layout).
    // maxW = 800-40 = 760 -> k = 760/1080 ~= 0.7037 -> top ~= 70.37.
    // The old fit-whole-document formula would have produced k ~= 0.017
    // (top ~= 1.7) -- unambiguously different.
    expect(positioned.top, closeTo(100 * 760 / 1080, 0.5));
  });

  testWidgets('puzzle doc: still fits the whole board, unaffected by Task 3.1', (tester) async {
    final layer = EditorLayer('layer1', at: const Offset(100, 100));
    final c = EditorController()
      ..doc = (ComicsDoc(name: 'test', type: DocType.puzzle, width: 1080, height: 1080)
        ..scale = 1.0
        ..layers.add(layer));

    final positioned = await _pumpAndFindLayer(tester, c);

    // Square doc, aspect=1 -> maxH=560 first assumed, pageW=560*1=560 <= maxW(760),
    // so pageW stays 560 -> k = 560/1080 ~= 0.5185 -> top ~= 51.85.
    // Materially different from the comics fit-width result above (~70.37),
    // confirming puzzle mode did not change.
    expect(positioned.top, closeTo(100 * 560 / 1080, 0.5));
  });
}

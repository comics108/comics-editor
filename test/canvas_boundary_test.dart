// vdd-comics-editor-vertical-scroll, Task 3.2: confirm InteractiveViewer's
// boundaryMargin (EdgeInsets.all(200), unchanged from before this flow) does
// not prevent panning through a real, much-taller-than-viewport document now
// that Task 3.1 makes _Page real-height instead of shrunk-to-fit.
//
// Per Flutter SDK source (interactive_viewer.dart's `_boundaryRect` getter):
// `boundaryMargin.inflateRect(Offset.zero & childSize)` -- the margin only
// ADDS slack beyond the child's own edges; it never subtracts from the
// pannable range within the child. So a 200px margin cannot clamp panning
// short of a real document's bottom, however tall -- confirmed structurally,
// not just empirically here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/widgets/canvas_view.dart';

void main() {
  testWidgets('a real drag gesture can pan well past the viewport height into a tall document',
      (tester) async {
    final c = EditorController()
      ..doc = (ComicsDoc(name: 'test', type: DocType.comics, width: 1080, height: 33000)
        ..layers.add(EditorLayer('layer1')));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditorScope(
          controller: c,
          child: const SizedBox(width: 800, height: 600, child: CanvasView()),
        ),
      ),
    ));
    await tester.pump();

    // Drag up repeatedly (revealing lower content) by far more than one
    // viewport height's worth of screen pixels. Each drag should accumulate
    // 1:1 at zoom=1 -- also real-gesture confirmation of currentTime's sign
    // convention (Open Design Question 1 in 03-specifications.md), not just
    // self-consistency against a directly-set Matrix4 as in current_time_test.dart.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(CanvasView), const Offset(0, -500));
      await tester.pump();
    }

    // currentTime should have advanced deep into the document, not been
    // clamped back to near 0 by boundaryMargin/constrained.
    expect(c.currentTime, closeTo(2500, 0.01));
  });
}

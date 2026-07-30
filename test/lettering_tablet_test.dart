// vdd-comics-editor-uiux-lettering, Task 5.4: iPad-landscape Lettering mode
// layout (02-visual.md "Screen: Lettering mode — iPad landscape (primary
// target)") -- two-pane composition (rail + large balloon editor, no
// canvas), on a tablet-width viewport.
//
// See lettering_desktop_test.dart's file-level comment for why entering
// Lettering mode (which touches a real FutureBuilder<LanguageRegistry>)
// needs tester.runAsync() to settle reliably across multiple tests in one
// file.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';
import 'package:comics_editor/src/ui/widgets/balloon_rail.dart';
import 'package:comics_editor/src/ui/widgets/canvas_view.dart';

Future<void> _setTabletViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1024, 800); // within the 601-1024 tablet band
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _toggleModeAndSettle(WidgetTester tester, EditorController controller) async {
  await tester.runAsync(() async {
    controller.toggleMode();
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if (!tester.binding.hasScheduledFrame) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets(
      'iPad landscape: two-pane layout (rail + balloon editor), no canvas, '
      'auto-selects the first balloon', (tester) async {
    await _setTabletViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')); // not a balloon
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.selectLayer(0);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);

    expect(controller.mode, EditorMode.lettering);
    expect(controller.selIndex, 1);
    expect(find.byType(BalloonRail), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing); // omitted on iPad, unlike desktop
    expect(find.text('BALLOONS (1)'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget); // BalloonEditorCard's own section label
  });

  testWidgets('zero balloon layers: empty rail + no-selection prompt, still no canvas',
      (tester) async {
    await _setTabletViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);

    expect(find.text('BALLOONS (0)'), findsOneWidget);
    expect(find.textContaining('Switch to Edit mode'), findsOneWidget);
    expect(find.text('Select a balloon or caption layer from the rail'), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });

  testWidgets('tapping a balloon in the rail swaps the editor card', (tester) async {
    await _setTabletViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();
    await _toggleModeAndSettle(tester, controller);

    expect(controller.selIndex, 0);
    await tester.tap(find.text('#02'));
    await tester.pumpAndSettle();
    expect(controller.selIndex, 1);
    expect(controller.selectedLayer, controller.doc!.layers[1]);
  });
}

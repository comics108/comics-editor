// vdd-comics-editor-ai-uiux, Task 6.1: smoke test that the real EditorScreen mounts the
// three-pane Cutting layout (region rail/Library tab | canvas | review card) without crashing
// when EditorMode.cutting is active, using the real sample.comics fixture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';

Future<void> _setDesktopViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('EditorScreen renders the Cutting three-pane layout with no regions yet',
      (tester) async {
    await _setDesktopViewport(tester);
    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });
    controller.setMode(EditorMode.cutting);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pump();

    expect(find.text('Cutting mode'), findsNothing); // not a literal label anywhere -- sanity
    expect(find.text('Library'), findsOneWidget);
    expect(find.textContaining('regions'), findsWidgets); // "Regions" tab / rail summary text
    expect(find.text('Cut / Segment'), findsOneWidget); // trigger screen, nothing cut yet
  });

  testWidgets('switching into Cutting mode preserves the document (no data loss on mode switch)',
      (tester) async {
    // Starts already in Cutting mode -- deliberately doesn't also exercise switching back to
    // Edit mode's docked timeline here, which has a pre-existing overflow bug in
    // lib/src/ui/widgets/timeline.dart unrelated to this flow (not touched by this flow, out of
    // scope to fix here).
    await _setDesktopViewport(tester);
    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });
    final layerCountBefore = controller.doc!.layers.length;
    controller.setMode(EditorMode.cutting);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pump();

    expect(controller.doc!.layers.length, layerCountBefore);
    expect(controller.mode, EditorMode.cutting);
  });
}

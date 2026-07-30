// vdd-comics-editor-uiux-lettering, Task 5.1: Edit/Lettering mode switch in
// the top bar (02-visual.md "Flow: Entering and using Lettering mode",
// step 1: "A new mode switch appears in the top bar next to the document
// name"). Toggle switches which body renders; Edit mode content (Scene/
// Canvas/Properties panels) is unaffected when never entering Lettering.
//
// Task 5.3 replaced the desktop Lettering body's placeholder text with the
// real rail + balloon editor composition -- assertions here check for that
// real content (an empty-document `newDoc()` has zero balloon layers, so
// the rail's empty state + "select a balloon" prompt). Entering Lettering
// mode touches a real FutureBuilder<LanguageRegistry> (production code),
// which needs `tester.runAsync()` to settle reliably in tests -- see
// `lettering_desktop_test.dart`'s file-level comment for why.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';
import 'package:comics_editor/src/ui/widgets/scene_panel.dart';

void main() {
  testWidgets('starts in Edit mode: Scene panel visible, no Lettering content',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = EditorController()..newDoc(DocType.comics);
    expect(controller.mode, EditorMode.edit);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ScenePanel), findsOneWidget);
    expect(find.textContaining('BALLOONS'), findsNothing);
  });

  testWidgets('tapping the Lettering segment switches the body, Edit unaffected until toggled back',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = EditorController()..newDoc(DocType.comics);
    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Lettering'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    expect(controller.mode, EditorMode.lettering);
    expect(find.byType(ScenePanel), findsNothing);
    // newDoc() has zero layers -- the rail's empty state + no-selection prompt.
    expect(find.text('BALLOONS (0)'), findsOneWidget);
    expect(find.text('Select a balloon or caption layer from the rail'), findsOneWidget);

    // Toggle back -- Edit mode content reappears unchanged.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(controller.mode, EditorMode.edit);
    expect(find.byType(ScenePanel), findsOneWidget);
    expect(find.textContaining('BALLOONS'), findsNothing);
  });

  test('toggleMode flips between edit and lettering, setMode is idempotent (no notify on no-op)',
      () {
    final controller = EditorController()..newDoc(DocType.comics);
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    expect(controller.mode, EditorMode.edit);
    controller.toggleMode();
    expect(controller.mode, EditorMode.lettering);
    expect(notifyCount, 1);

    controller.setMode(EditorMode.lettering); // no-op
    expect(notifyCount, 1);

    controller.toggleMode();
    expect(controller.mode, EditorMode.edit);
    expect(notifyCount, 2);
  });
}

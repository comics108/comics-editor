// vdd-comics-editor-uiux-lettering, Task 5.3: desktop Lettering mode layout
// (02-visual.md "Screen: Lettering mode — Desktop") -- the three-pane
// composition (rail | canvas | balloon editor) and auto-select-first-balloon
// behavior on entering Lettering mode.
//
// Debugging note: entering Lettering mode renders a real
// FutureBuilder<LanguageRegistry> (production code, not a test shortcut) --
// `EditorController.languageRegistry` reads `assets/languages.json` via
// `rootBundle`. That asset-bundle read is itself cached by Flutter's own
// `CachingAssetBundle`, and a `Future` that completes inside one
// `testWidgets` body's `Zone` never notifies `.then()`/`FutureBuilder`
// listeners attached from a *later* test's `Zone` -- so any test after the
// first one to touch this path hangs forever on `pumpAndSettle` unless the
// settle happens inside `tester.runAsync()`, which steps outside the
// per-test FakeAsync zone and lets the Future resolve via normal real-world
// async semantics. Same root cause class as `balloon_editor_card_test.dart`
// and `properties_panel_balloon_test.dart`; fixed the same way here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/editor_mode.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';
import 'package:comics_editor/src/ui/widgets/balloon_rail.dart';
import 'package:comics_editor/src/ui/widgets/canvas_view.dart';

Future<void> _setDesktopViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _toggleModeAndSettle(WidgetTester tester, EditorController controller) async {
  await tester.runAsync(() async {
    controller.toggleMode();
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      // wait for the LanguageRegistry FutureBuilder(s) to actually resolve
      if (!tester.binding.hasScheduledFrame) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets(
      'entering Lettering mode on a doc with balloons shows rail + canvas + '
      'balloon editor, auto-selecting the first balloon', (tester) async {
    await _setDesktopViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')); // not a balloon
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');
    controller.selectLayer(0); // starts on the non-balloon layer

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);

    expect(controller.mode, EditorMode.lettering);
    // Auto-selected the first balloon/caption layer (index 1), not the
    // non-balloon layer that was selected before entering.
    expect(controller.selIndex, 1);
    expect(controller.selectedLayer, controller.doc!.layers[1]);

    expect(find.byType(BalloonRail), findsOneWidget);
    expect(find.byType(CanvasView), findsOneWidget);
    expect(find.text('BALLOONS (2)'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget); // BalloonEditorCard's section label
  });

  testWidgets('a document with zero balloon layers shows the empty rail and no-selection prompt',
      (tester) async {
    await _setDesktopViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer(); // default kind == null

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);

    expect(find.text('BALLOONS (0)'), findsOneWidget);
    expect(find.textContaining('Switch to Edit mode'), findsOneWidget);
    expect(find.text('Select a balloon or caption layer from the rail'), findsOneWidget);
  });

  testWidgets('toggling back to Edit mode restores the normal three-pane Edit layout',
      (tester) async {
    await _setDesktopViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);
    expect(find.byType(BalloonRail), findsOneWidget);

    await _toggleModeAndSettle(tester, controller);
    expect(find.byType(BalloonRail), findsNothing);
    expect(controller.mode, EditorMode.edit);
  });

  testWidgets('tapping a different balloon in the rail swaps the editor card to that layer',
      (tester) async {
    await _setDesktopViewport(tester);
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

  testWidgets(
      'Task 5.6: the [<] N/M [>] stepper appears next to the balloon editor '
      'and steps through balloons, clamped at the ends', (tester) async {
    await _setDesktopViewport(tester);
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
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(controller.selIndex, 1);
    expect(find.text('2/2'), findsOneWidget);

    // Clamped -- tapping next again at the last balloon is a no-op.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(controller.selIndex, 1);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(controller.selIndex, 0);
    expect(find.text('1/2'), findsOneWidget);
  });
}

// vdd-comics-editor-uiux-lettering, Task 4.3: PropertiesPanel shows
// BalloonEditorCard in place of the generic artwork fields when the
// selected layer's kind is "balloon" -- the full generate flow works from
// within Edit mode, no Lettering mode needed (04-plan.md's verification for
// this task).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/widgets/properties_panel.dart';

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('non-balloon layer shows the generic ARTWORK · PER LANGUAGE editor, not the card',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer(); // default kind == null

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ARTWORK · PER LANGUAGE'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsNothing); // BalloonEditorCard's own section label
  });

  testWidgets('balloon-kind layer shows BalloonEditorCard instead of the generic fields',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    controller.setLayerKind('balloon');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    expect(find.text('ARTWORK · PER LANGUAGE'), findsNothing);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('speech'), findsOneWidget); // default style chip in the card header
  });

  testWidgets(
      'switching a layer to balloon kind via the dropdown swaps in BalloonEditorCard live',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ARTWORK · PER LANGUAGE'), findsOneWidget);

    await tester.runAsync(() async {
      // tdd-dot-comics-format, Plan Task 4.3: the MASK section added its
      // own DropdownButton<String?> -- target the first one (KIND, which
      // renders before MASK) rather than "the" DropdownButton.
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Balloon').last);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    expect(find.text('ARTWORK · PER LANGUAGE'), findsNothing);
    expect(find.text('LANGUAGE'), findsOneWidget);
  });

  testWidgets('full generate flow works from Edit mode: type text, generate, see success',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });
    controller.selectLayer(0);
    controller.setLayerKind('balloon');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    expect(find.text('LANGUAGE'), findsOneWidget);
    // The fixture's layer 0 already has real artwork for 'en' (no text yet)
    // -- it's already a tab, no need to "+ Add" it.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    // The panel also has anim-parameter NumberFields elsewhere -- scope to
    // the balloon card's own text field specifically.
    await tester.enterText(find.byType(TextField).first, 'Hello from Edit mode');
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Generate artwork with AI'));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        if (find.text('Regenerate').evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    });

    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Generated just now'), findsOneWidget);
    expect(controller.selectedLayer!.translations['en'], 'Hello from Edit mode');
  }, timeout: const Timeout(Duration(seconds: 30)));
}

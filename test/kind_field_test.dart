// vdd-comics-editor-uiux-lettering, Task 3.2: kind-setting dropdown in the
// per-layer editor (properties_panel.dart's _KindField) + the underlying
// EditorController.setLayerKind mutation. Verification per the plan: set/
// change/clear a layer's kind, confirm the chip updates, confirm it
// persists across save/reopen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('setLayerKind sets/changes/clears kind, no-op with nothing selected', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    final layer = controller.selectedLayer!;
    expect(layer.kind, isNull);

    controller.setLayerKind('balloon');
    expect(layer.kind, 'balloon');

    controller.setLayerKind('caption');
    expect(layer.kind, 'caption');

    controller.setLayerKind(null);
    expect(layer.kind, isNull);

    controller.addSound(); // selects a sound -> selectedLayer becomes null
    controller.setLayerKind('balloon'); // must not throw
  });

  test('setLayerKind is undoable', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    controller.setLayerKind('balloon');
    expect(controller.selectedLayer!.kind, 'balloon');
    controller.undo(); // undo() clears selection (existing behavior) -- reselect to check
    controller.selectLayer(controller.doc!.layers.length - 1);
    expect(controller.selectedLayer!.kind, isNull);
  });

  test('setLayerKind persists across a real saveComics -> reopen round trip', () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.selectLayer(0);
    controller.setLayerKind('balloon');
    expect(controller.selectedLayer!.kind, 'balloon');

    final savedPath =
        '${Directory.systemTemp.createTempSync('kindfield').path}/roundtrip.comics';
    expect(await controller.saveToPath(savedPath), isTrue);

    final reopened = EditorController();
    expect(await reopened.openPath(savedPath), isTrue);
    expect(reopened.doc!.layers[0].kind, 'balloon');
    // Every other layer stays untouched (no stray kind).
    for (var i = 1; i < reopened.doc!.layers.length; i++) {
      expect(reopened.doc!.layers[i].kind, isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('picking a kind from the dropdown updates the layer and its list chip',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    // Default/unset kind shows the neutral [Art] chip in the list.
    expect(find.text('Art'), findsWidgets);
    expect(find.text('Bln'), findsNothing);

    // tdd-dot-comics-format, Plan Task 4.3: the MASK section added its own
    // DropdownButton<String?>, so this must target the first one (KIND
    // renders before MASK in _LayerEditor's list) rather than "the"
    // DropdownButton.
    await tester.tap(find.byType(DropdownButton<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balloon').last);
    await tester.pumpAndSettle();

    expect(controller.selectedLayer!.kind, 'balloon');
    expect(find.text('Bln'), findsOneWidget);
  });
}

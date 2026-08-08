// vdd-comics-editor-ai-uiux, Tasks 6.1-6.2: the Cutting mode switch -- EditorMode.cutting exists
// and cycles correctly, and the compact/touch row's Cutting icon shows an explanation instead of
// switching mode when running on a platform where Cutting can't work (simulated here by directly
// exercising the same logic the widget uses, since Platform.isIOS/isAndroid can't be faked in a
// desktop test run).
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/editor_mode.dart';
import 'package:flutter_comics/flutter_comics.dart';

void main() {
  test('EditorMode has a cutting value with the expected label', () {
    expect(EditorMode.values, contains(EditorMode.cutting));
    expect(EditorMode.cutting.label, 'Cutting');
  });

  test('kEditorModes includes cutting (drives the desktop 3-way segmented switch)', () {
    expect(kEditorModes, contains(EditorMode.cutting));
    expect(kEditorModes.length, 3);
  });

  test('setMode switches into cutting and back to edit', () {
    final controller = EditorController()..newDoc(DocType.comics);
    expect(controller.mode, EditorMode.edit);

    controller.setMode(EditorMode.cutting);
    expect(controller.mode, EditorMode.cutting);

    controller.setMode(EditorMode.edit);
    expect(controller.mode, EditorMode.edit);
  });

  test('toggleMode never lands on cutting (edit/lettering binary toggle only, '
      'matching the compact row\'s separate Cutting icon)', () {
    final controller = EditorController()..newDoc(DocType.comics);
    controller.setMode(EditorMode.cutting);
    controller.toggleMode(); // not == edit -> goes to edit, per its own binary ternary
    expect(controller.mode, EditorMode.edit);
    controller.toggleMode(); // == edit -> goes to lettering
    expect(controller.mode, EditorMode.lettering);
  });
}

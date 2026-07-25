import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';

void main() {
  group('EditorController undo/redo', () {
    late EditorController c;

    setUp(() {
      c = EditorController();
      c.newDoc(DocType.comics);
    });

    tearDown(() => c.dispose());

    test('newDoc starts with empty, clean history', () {
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
    });

    test('addLayer is undoable/redoable', () {
      expect(c.doc!.layers, isEmpty);

      c.addLayer();
      expect(c.doc!.layers, hasLength(1));
      expect(c.canUndo, isTrue);

      c.undo();
      expect(c.doc!.layers, isEmpty);
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isTrue);

      c.redo();
      expect(c.doc!.layers, hasLength(1));
      expect(c.canRedo, isFalse);
    });

    test('multiple actions undo in reverse order', () {
      c.addLayer(); // layer 1
      c.addLayer(); // layer 2
      c.addLayer(); // layer 3
      expect(c.doc!.layers, hasLength(3));

      c.undo();
      expect(c.doc!.layers, hasLength(2));
      c.undo();
      expect(c.doc!.layers, hasLength(1));
      c.undo();
      expect(c.doc!.layers, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test('undo on empty history is a no-op', () {
      c.undo();
      expect(c.doc!.layers, isEmpty);
    });

    test('a new action after undo clears the redo stack', () {
      c.addLayer();
      c.undo();
      expect(c.canRedo, isTrue);

      c.addLayer();
      expect(c.canRedo, isFalse);
    });

    test('deleteSelected on a layer is undoable', () {
      c.addLayer();
      c.selectLayer(0);
      c.deleteSelected();
      expect(c.doc!.layers, isEmpty);

      c.undo(); // undoes deleteSelected
      expect(c.doc!.layers, hasLength(1));
    });

    test('moveLayer no-op at boundary does not create a history entry', () {
      c.addLayer();
      c.selectLayer(0);
      final undoDepthBefore = c.canUndo;
      c.moveLayer(-1); // already at index 0, can't move further left
      // moveLayer's own guard should prevent an extra history push beyond
      // what addLayer already pushed.
      c.undo(); // undoes addLayer
      expect(c.doc!.layers, isEmpty);
      expect(undoDepthBefore, isTrue);
    });

    test('newDoc() clears history from a previous document', () {
      c.addLayer();
      expect(c.canUndo, isTrue);

      c.newDoc(DocType.puzzle);
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
    });

    test('gesture-style history (beginGestureHistory/commitGestureHistory) '
        'produces one undo step for the whole gesture', () {
      c.addLayer();
      c.selectLayer(0);
      final before = c.doc!.layers[0].translate;

      c.beginGestureHistory();
      c.dragSelected(const Offset(5, 0));
      c.dragSelected(const Offset(5, 0));
      c.dragSelected(const Offset(5, 0));
      c.commitGestureHistory();

      expect(c.doc!.layers[0].translate, before + const Offset(15, 0));

      c.undo(); // undoes the whole drag in one step
      expect(c.doc!.layers[0].translate, before);
    });
  });
}

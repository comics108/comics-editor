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

    // tdd-dot-comics-format, Plan Task 3.5: an organizational anchor is a
    // Kind-marked layer with no image content, distinct from addLayer's
    // real-artwork layer.
    test('addOrganizationalLayer creates a kind-marked layer with no images', () {
      c.addOrganizationalLayer();
      expect(c.doc!.layers, hasLength(1));
      expect(c.doc!.layers[0].kind, EditorLayer.organizationalKind);
      expect(c.doc!.layers[0].images, isEmpty);
    });

    // tdd-dot-comics-format, Plan Task 4.3: a solid-color layer's images
    // stay populated (never cleared) -- solidColor takes precedence for
    // rendering, so nothing is lost if it's cleared later.
    test('addSolidColorLayer creates a layer with solidColor set, images untouched', () {
      c.addSolidColorLayer('#ffffff');
      expect(c.doc!.layers, hasLength(1));
      expect(c.doc!.layers[0].solidColor, '#ffffff');
      expect(c.doc!.layers[0].images, isNotEmpty);
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

    // tdd-dot-comics-format, Plan Task 1.1/3.1: a snapshot (undo/redo) must
    // preserve layer identity -- otherwise a parentId reference set before
    // an undo would silently point at nothing afterward.
    test('layer id survives undo/redo (identity, not a new layer)', () {
      c.addLayer();
      final idBefore = c.doc!.layers[0].id;

      c.addLayer();
      c.undo(); // back to 1 layer
      expect(c.doc!.layers[0].id, idBefore);

      c.redo(); // forward to 2 layers again
      expect(c.doc!.layers[0].id, idBefore);
    });

    // tdd-dot-comics-format, Plan Task 3.1, orphan policy: deleting a parent
    // clears the child's parentId and leaves its position untouched -- no
    // cascade delete, no re-computation.
    test('deleting a parent layer clears the child\'s parentId, keeps its position', () {
      c.addLayer(); // parent, index 0
      c.addLayer(); // child, index 1
      final parentId = c.doc!.layers[0].id;
      final childTranslateBefore = c.doc!.layers[1].translate;
      c.doc!.layers[1].parentId = parentId;

      c.selectLayer(0);
      c.deleteSelected();

      expect(c.doc!.layers, hasLength(1));
      expect(c.doc!.layers[0].parentId, isNull);
      expect(c.doc!.layers[0].translate, childTranslateBefore);
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

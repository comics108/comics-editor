import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/edit_history.dart';
import 'package:comics_editor/src/ui/models.dart';

ComicsDoc _doc({int layers = 0}) {
  final d = ComicsDoc(name: 'test.comics', type: DocType.comics);
  for (var i = 0; i < layers; i++) {
    d.layers.add(EditorLayer('layer_$i.png'));
  }
  return d;
}

void main() {
  group('EditHistory', () {
    test('starts empty: canUndo/canRedo false', () {
      final h = EditHistory();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });

    test('commit without begin is a no-op', () {
      final h = EditHistory();
      h.commitTransaction();
      expect(h.canUndo, isFalse);
    });

    test('begin+commit pushes one undo entry and clears redo', () {
      final h = EditHistory();
      h.beginTransaction(_doc());
      h.commitTransaction();
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
    });

    test('undo returns the snapshot and moves current state to redo stack', () {
      final h = EditHistory();
      final before = _doc(layers: 0);
      h.beginTransaction(before);
      h.commitTransaction();

      final current = _doc(layers: 1);
      final restored = h.undo(current);

      expect(restored, same(before));
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isTrue);
    });

    test('redo returns the snapshot and moves current state back to undo stack', () {
      final h = EditHistory();
      final before = _doc(layers: 0);
      h.beginTransaction(before);
      h.commitTransaction();
      final afterAdd = _doc(layers: 1);
      h.undo(afterAdd);

      final restored = h.redo(before);
      expect(restored, same(afterAdd));
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
    });

    test('undo on empty stack returns null', () {
      final h = EditHistory();
      expect(h.undo(_doc()), isNull);
    });

    test('redo on empty stack returns null', () {
      final h = EditHistory();
      expect(h.redo(_doc()), isNull);
    });

    test('a new transaction after undo clears the redo stack', () {
      final h = EditHistory();
      h.beginTransaction(_doc(layers: 0));
      h.commitTransaction();
      h.undo(_doc(layers: 1));
      expect(h.canRedo, isTrue);

      h.beginTransaction(_doc(layers: 1));
      h.commitTransaction();
      expect(h.canRedo, isFalse);
    });

    test('clear empties both stacks and any pending transaction', () {
      final h = EditHistory();
      h.beginTransaction(_doc());
      h.commitTransaction();
      h.undo(_doc());
      h.beginTransaction(_doc());
      h.clear();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
      h.commitTransaction(); // pending was cleared too — no-op
      expect(h.canUndo, isFalse);
    });
  });

  group('ComicsDoc.clone (snapshot independence)', () {
    test('mutating the original after clone does not affect the clone', () {
      final original = _doc(layers: 1)..layers[0].translate = const Offset(10, 20);
      final snapshot = original.clone();

      original.layers[0].translate = const Offset(999, 999);
      original.layers.add(EditorLayer('extra.png'));
      original.width = 4242;

      expect(snapshot.layers.length, 1);
      expect(snapshot.layers[0].translate, const Offset(10, 20));
      expect(snapshot.width, isNot(4242));
    });

    test('clone deep-copies layer images/anims independently', () {
      final original = _doc(layers: 1);
      original.layers[0].images[0].file = 'a.png';
      final snapshot = original.clone();

      original.layers[0].images[0].file = 'b.png';
      original.layers[0].anims.first.x = 500;

      expect(snapshot.layers[0].images[0].file, 'a.png');
      expect(snapshot.layers[0].anims.first.x, isNot(500));
    });
  });
}

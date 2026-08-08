// tdd-dot-comics-format, Plan Task 3.3: Layer.ParentId hierarchy -- render
// order, cycle prevention, and the setLayerParent/orphan-clearing behavior.
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';

void main() {
  group('EditorController parenting', () {
    late EditorController c;

    setUp(() {
      c = EditorController();
      c.newDoc(DocType.comics);
    });

    tearDown(() => c.dispose());

    test('hierarchicalLayerOrder matches flat document order when nothing is parented', () {
      c.addLayer();
      c.addLayer();
      c.addLayer();
      final order = c.hierarchicalLayerOrder(c.doc!.layers);
      expect(order, [(0, 0), (1, 0), (2, 0)]);
    });

    test('hierarchicalLayerOrder places children immediately after their parent, indented', () {
      c.addLayer(); // 0: head
      c.addLayer(); // 1: arms
      c.addLayer(); // 2: forearm
      c.addLayer(); // 3: unrelated root
      final layers = c.doc!.layers;
      layers[1].parentId = layers[0].id; // arms -> head
      layers[2].parentId = layers[1].id; // forearm -> arms

      final order = c.hierarchicalLayerOrder(layers);
      expect(order, [(0, 0), (1, 1), (2, 2), (3, 0)]);
    });

    test('a collapsed parent hides its descendants from the render order', () {
      c.addLayer(); // 0: parent
      c.addLayer(); // 1: child
      final layers = c.doc!.layers;
      layers[1].parentId = layers[0].id;
      c.toggleLayerCollapsed(layers[0].id);

      final order = c.hierarchicalLayerOrder(layers);
      expect(order, [(0, 0)]);
    });

    test('wouldCreateParentCycle rejects a layer becoming its own parent', () {
      c.addLayer();
      final layer = c.doc!.layers[0];
      expect(c.wouldCreateParentCycle(layer, layer.id, c.doc!.layers), isTrue);
    });

    test('wouldCreateParentCycle rejects parenting to a descendant (2-hop and 3-hop)', () {
      c.addLayer(); // 0
      c.addLayer(); // 1
      c.addLayer(); // 2
      final layers = c.doc!.layers;
      layers[1].parentId = layers[0].id; // 1 -> 0
      layers[2].parentId = layers[1].id; // 2 -> 1

      // 0 -> 1 would be a 2-hop cycle (1 is 0's child).
      expect(c.wouldCreateParentCycle(layers[0], layers[1].id, layers), isTrue);
      // 0 -> 2 would be a 3-hop cycle (2 is 0's grandchild).
      expect(c.wouldCreateParentCycle(layers[0], layers[2].id, layers), isTrue);
      // 0 -> some unrelated layer is fine.
      c.addLayer(); // 3, unrelated
      expect(c.wouldCreateParentCycle(layers[0], layers[3].id, layers), isFalse);
    });

    test('setLayerParent is a no-op when it would create a cycle', () {
      c.addLayer(); // 0
      c.addLayer(); // 1
      final layers = c.doc!.layers;
      layers[1].parentId = layers[0].id; // 1 -> 0

      c.setLayerParent(layers[0], layers[1].id); // 0 -> 1 would cycle
      expect(layers[0].parentId, isNull);
    });

    test('setLayerParent applies a valid parent and is undoable', () {
      c.addLayer(); // 0
      c.addLayer(); // 1
      final layers = c.doc!.layers;

      c.setLayerParent(layers[1], layers[0].id);
      expect(layers[1].parentId, layers[0].id);

      c.undo();
      expect(c.doc!.layers[1].parentId, isNull);
    });

    // tdd-dot-comics-format, Plan Task 3.4: dragging a parent moves the
    // whole parentId chain by the same delta, matching THE BROKEN TUSK's
    // real 3-level rig (голова -> руки сложен -> предплечье).
    test('dragSelected moves the whole parentId chain by the same delta', () {
      c.addLayer(); // 0: голова
      c.addLayer(); // 1: руки сложен
      c.addLayer(); // 2: предплечье
      c.addLayer(); // 3: unrelated
      final layers = c.doc!.layers;
      layers[1].parentId = layers[0].id;
      layers[2].parentId = layers[1].id;

      final before = [for (final l in layers) l.translate];
      c.selectLayer(0);
      const delta = Offset(12, -7);
      c.dragSelected(delta);

      expect(layers[0].translate, before[0] + delta);
      expect(layers[1].translate, before[1] + delta);
      expect(layers[2].translate, before[2] + delta);
      expect(layers[3].translate, before[3]); // unrelated, untouched
    });
  });
}

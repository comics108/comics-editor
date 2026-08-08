// tdd-dot-comics-format, Plan Task 1.1: EditorLayer.id is a stable identity,
// a prerequisite for parentId. Corrected during Task 3.1's grounding: clone()
// is only ever used by ComicsDoc.clone() for undo/redo snapshots
// (edit_history.dart/controller.dart), which must preserve identity -- a
// snapshot is the *same* document, not a new one -- so clone() preserves id,
// it does not generate a new one (the plan's original assumption was wrong,
// caught before it shipped).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/models.dart';

void main() {
  test('a new EditorLayer gets a non-empty id', () {
    final layer = EditorLayer('layer');
    expect(layer.id, isNotEmpty);
  });

  test('two different layers get different ids', () {
    final a = EditorLayer('a');
    final b = EditorLayer('b');
    expect(a.id, isNot(b.id));
  });

  test('clone() preserves id (undo/redo snapshot is the same layer)', () {
    final original = EditorLayer('layer');
    final clone = original.clone();
    expect(clone.id, original.id);
  });

  test('a new EditorLayer has no parentId by default', () {
    final layer = EditorLayer('layer');
    expect(layer.parentId, isNull);
  });

  test('clone() preserves parentId', () {
    final original = EditorLayer('layer')..parentId = 'some-parent-id';
    final clone = original.clone();
    expect(clone.parentId, 'some-parent-id');
  });

  // tdd-dot-comics-format, Plan Task 2.1: scrollType/preferredOrientation
  // default to vertical/portrait -- every existing file's implicit,
  // only-ever-exercised behavior.
  test('a new ComicsDoc defaults to vertical scroll, portrait orientation', () {
    final doc = ComicsDoc(name: 'doc', type: DocType.comics);
    expect(doc.scrollType, ScrollType.vertical);
    expect(doc.preferredOrientation, PreferredOrientation.portrait);
  });

  test('ComicsDoc.clone() preserves scrollType/preferredOrientation', () {
    final doc = ComicsDoc(name: 'doc', type: DocType.comics)
      ..scrollType = ScrollType.horizontal
      ..preferredOrientation = PreferredOrientation.auto;
    final clone = doc.clone();
    expect(clone.scrollType, ScrollType.horizontal);
    expect(clone.preferredOrientation, PreferredOrientation.auto);
  });

  // tdd-dot-comics-format, Plan Task 4.1: solidColor/mask default to unset
  // (today's exact behavior) and survive clone() as independent copies.
  test('a new EditorLayer has no solidColor/mask by default', () {
    final layer = EditorLayer('layer');
    expect(layer.solidColor, isNull);
    expect(layer.mask, isNull);
  });

  test('clone() preserves solidColor and deep-copies mask', () {
    final original = EditorLayer('layer')
      ..solidColor = '#ffffff'
      ..mask = LayerMask.rect(const Rect.fromLTWH(0, 0, 100, 50));
    final clone = original.clone();

    expect(clone.solidColor, '#ffffff');
    expect(clone.mask!.shape, 'rect');
    expect(clone.mask!.rect, const Rect.fromLTWH(0, 0, 100, 50));
    expect(clone.mask, isNot(same(original.mask))); // deep copy, not shared
  });

  // tdd-dot-comics-format, Plan Task 5.2: basis defaults to scroll (every
  // existing anim is implicitly scroll-driven), loop defaults to true.
  test('a new Anim defaults to scroll basis, loop=true', () {
    final anim = Anim(AnimType.translate);
    expect(anim.basis, AnimBasis.scroll);
    expect(anim.loop, isTrue);
  });

  test('clone() preserves basis/loop', () {
    final anim = Anim(AnimType.alpha)
      ..basis = AnimBasis.time
      ..loop = false;
    final clone = anim.clone();
    expect(clone.basis, AnimBasis.time);
    expect(clone.loop, isFalse);
  });

  // tdd-dot-lottie-import-export, Plan Task 1.1/1.3: groupId/textRegion
  // default to unset (today's exact behavior) and survive clone()
  // independently.
  test('a new EditorLayer has no groupId/textRegion by default', () {
    final layer = EditorLayer('layer');
    expect(layer.groupId, isNull);
    expect(layer.textRegion, isNull);
  });

  test('clone() preserves groupId and deep-copies textRegion', () {
    final original = EditorLayer('layer')
      ..groupId = 'group-1'
      ..textRegion = TextRegion(
        shape: 'rect',
        rect: const Rect.fromLTWH(0, 0, 40, 20),
        isHandLettered: true,
      );
    final clone = original.clone();

    expect(clone.groupId, 'group-1');
    expect(clone.textRegion!.shape, 'rect');
    expect(clone.textRegion!.rect, const Rect.fromLTWH(0, 0, 40, 20));
    expect(clone.textRegion!.isHandLettered, isTrue);
    expect(clone.textRegion, isNot(same(original.textRegion))); // deep copy
  });

  // tdd-dot-lottie-import-export, Plan Task 1.5: default 720x1600 matches
  // the real value found in samples/sample_playback_viewport.lottie_unzip.
  test('a new ComicsDoc defaults to a 720x1600 preferred viewport size', () {
    final doc = ComicsDoc(name: 'doc', type: DocType.comics);
    expect(doc.preferredViewportWidth, 720);
    expect(doc.preferredViewportHeight, 1600);
  });

  test('ComicsDoc.clone() preserves preferredViewportWidth/Height', () {
    final doc = ComicsDoc(name: 'doc', type: DocType.comics)
      ..preferredViewportWidth = 1080
      ..preferredViewportHeight = 1920;
    final clone = doc.clone();
    expect(clone.preferredViewportWidth, 1080);
    expect(clone.preferredViewportHeight, 1920);
  });
}

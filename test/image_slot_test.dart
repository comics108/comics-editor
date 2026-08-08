// vdd-comics-editor-uiux-lettering, Task 1.2: additive Images[] slot
// resolution via LanguageRegistry -- en/ru/hi keep their existing
// Cultures-aligned indices, and any registry language beyond that appends
// at a stable, append-only position with no native/C# involvement.
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/i18n/language_registry.dart';
import 'package:flutter_comics/flutter_comics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('en/ru/hi resolve to the existing slots 0/1/2', () async {
    final registry = await LanguageRegistry.load();
    final layer = EditorLayer('bg.png');

    expect(layer.imageSlotFor('en', registry), same(layer.images[0]));
    expect(layer.imageSlotFor('ru', registry), same(layer.images[1]));
    expect(layer.imageSlotFor('hi', registry), same(layer.images[2]));
    expect(layer.images.length, 3);
  });

  test('a language beyond en/ru/hi extends images[] with placeholders up to its slot', () async {
    final registry = await LanguageRegistry.load();
    final layer = EditorLayer('bg.png'); // starts with 3 image slots
    final ukIndex = registry.indexFor('uk')!;

    final slot = layer.imageSlotFor('uk', registry);
    expect(layer.images.length, ukIndex + 1);
    expect(slot, same(layer.images[ukIndex]));
    // The gap slots between hi (2) and uk are real empty placeholders, not skipped.
    for (var i = 3; i < ukIndex; i++) {
      expect(layer.images[i].file, isEmpty);
    }
  });

  test('resolving the same new language twice returns the same slot, not a duplicate', () async {
    final registry = await LanguageRegistry.load();
    final layer = EditorLayer('bg.png');

    final first = layer.imageSlotFor('th', registry);
    first.file = 'th_balloon.png';
    final lengthAfterFirst = layer.images.length;

    final second = layer.imageSlotFor('th', registry);
    expect(second, same(first));
    expect(second.file, 'th_balloon.png');
    expect(layer.images.length, lengthAfterFirst);
  });

  test('writing a farther language first still leaves closer languages addressable', () async {
    final registry = await LanguageRegistry.load();
    final layer = EditorLayer('bg.png');

    layer.imageSlotFor('ar', registry).file = 'ar.png'; // last in the canonical table
    final thSlot = layer.imageSlotFor('th', registry); // earlier index, already allocated as empty
    expect(thSlot.file, isEmpty);
    expect(layer.imageSlotFor('ar', registry).file, 'ar.png');
  });

  test('unknown language code throws rather than silently misplacing artwork', () async {
    final registry = await LanguageRegistry.load();
    final layer = EditorLayer('bg.png');
    expect(() => layer.imageSlotFor('xx', registry), throwsArgumentError);
  });

  test('mapping is stable after a simulated reopen (fresh EditorLayer + registry)', () async {
    final registry = await LanguageRegistry.load();

    final original = EditorLayer('bg.png');
    original.imageSlotFor('uk', registry).file = 'uk_balloon.png';
    original.imageSlotFor('hi', registry).file = 'hi_balloon.png';

    // Simulate a save→reopen: a brand-new EditorLayer/registry pair, images
    // copied over positionally (as models_mapping.dart's comicsFromCore
    // does from raw JSON), no per-document bookkeeping involved.
    final reopened = EditorLayer('bg.png');
    reopened.images.clear();
    reopened.images.addAll(original.images.map((i) => i.clone()));
    final freshRegistry = await LanguageRegistry.load();

    expect(reopened.imageSlotFor('uk', freshRegistry).file, 'uk_balloon.png');
    expect(reopened.imageSlotFor('hi', freshRegistry).file, 'hi_balloon.png');
  });
}

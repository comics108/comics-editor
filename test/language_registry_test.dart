// vdd-comics-editor-uiux-lettering, Task 1.4: the language list must be
// dynamic -- driven by assets/languages.json, never a hardcoded count in
// Dart. These tests load the real bundled asset (not a fixture copy) so a
// change to the JSON file alone, with zero Dart changes, is what the tests
// actually exercise.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/i18n/language_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the real bundled assets/languages.json', () async {
    final registry = await LanguageRegistry.load();

    // en/ru/hi are fixed by the native Cultures enum and must be first,
    // in this exact order -- everything after them is open-ended.
    expect(registry.languages[0].code, 'en');
    expect(registry.languages[1].code, 'ru');
    expect(registry.languages[2].code, 'hi');
    expect(registry.languages.length, greaterThan(3));
  });

  test(
    'indexFor/codeFor resolve en/ru/hi to 0/1/2, matching Cultures',
    () async {
      final registry = await LanguageRegistry.load();
      expect(registry.indexFor('en'), 0);
      expect(registry.indexFor('ru'), 1);
      expect(registry.indexFor('hi'), 2);
      expect(registry.codeFor(0), 'en');
      expect(registry.codeFor(1), 'ru');
      expect(registry.codeFor(2), 'hi');
    },
  );

  test('unknown code/index resolve to null, not a crash', () async {
    final registry = await LanguageRegistry.load();
    expect(registry.indexFor('xx'), isNull);
    expect(registry.isKnown('xx'), isFalse);
    expect(registry.codeFor(9999), isNull);
    expect(registry.codeFor(-1), isNull);
  });

  test('is genuinely data-driven: an entry appended to the JSON with no Dart '
      'change is picked up as a new trailing language', () {
    // Simulates "add a language" by decoding a JSON string with one extra
    // trailing entry appended to the real file's shape -- proves the
    // registry has no hardcoded language count/list anywhere in Dart.
    const withExtraLanguage = '''
    {
      "languages": [
        { "code": "en", "name": "English", "nativeName": "English" },
        { "code": "ru", "name": "Russian", "nativeName": "Русский" },
        { "code": "hi", "name": "Hindi", "nativeName": "हिन्दी" },
        { "code": "xx", "name": "Testlang", "nativeName": "Testlang" }
      ]
    }
    ''';
    final registry = LanguageRegistry.fromJson(withExtraLanguage);
    expect(registry.languages.length, 4);
    expect(registry.indexFor('xx'), 3);
    expect(registry.codeFor(3), 'xx');
  });

  test(
    'real asset file is valid JSON with a non-trivial language list',
    () async {
      final raw = await rootBundle.loadString('assets/languages.json');
      expect(raw, contains('"languages"'));
      final registry = LanguageRegistry.fromJson(raw);
      // Not asserting an exact count -- that would re-introduce the hardcoded
      // number this design explicitly avoids. Just that it's plausible.
      expect(registry.languages.length, greaterThanOrEqualTo(10));
    },
  );

  test('inactive languages keep their stable slots', () {
    const raw = '''
    {"languages":[
      {"code":"en","name":"English","nativeName":"English"},
      {"code":"ru","name":"Russian","nativeName":"Русский"},
      {"code":"hi","name":"Hindi","nativeName":"हिन्दी"},
      {"code":"uk","name":"Ukrainian","nativeName":"Українська","active":false}
    ]}''';
    final registry = LanguageRegistry.fromJson(raw);

    expect(registry.indexFor('uk'), 3);
    expect(registry.languages[3].active, isFalse);
  });

  test('rejects shifting the three legacy language slots', () {
    const raw = '''
    {"languages":[
      {"code":"ru","name":"Russian","nativeName":"Русский"},
      {"code":"en","name":"English","nativeName":"English"},
      {"code":"hi","name":"Hindi","nativeName":"हिन्दी"}
    ]}''';
    expect(() => LanguageRegistry.fromJson(raw), throwsFormatException);
  });
}

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One entry in the language table: an ISO code plus display names.
class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    this.active = true,
  });
  final String code;
  final String name;
  final String nativeName;
  final bool active;
}

/// vdd-comics-editor-uiux-lettering: data-driven language list, backing the
/// additive Images[] slot extension (Task 1.2) and any future translation
/// UI. Loaded from `assets/languages.json` -- adding/removing a language is
/// a data change, not a code change. Order is load-bearing: index in
/// [languages] is the Images[] slot index, and the first three entries
/// (en/ru/hi) are fixed by the native Cultures enum, so they must stay
/// first and in that order.
class LanguageRegistry {
  LanguageRegistry._(this.languages)
    : _indexByCode = {
        for (var i = 0; i < languages.length; i++) languages[i].code: i,
      };

  final List<LanguageInfo> languages;
  final Map<String, int> _indexByCode;

  /// Deliberately *not* cached at the class/static level across
  /// [EditorController] instances -- a static cache means the very first
  /// caller's `Future` is the one everyone else shares for the rest of the
  /// process, and in `flutter test`, each `testWidgets` body runs in its
  /// own `Zone`; a `Future` completed inside test A's zone never notifies
  /// `.then()`/`FutureBuilder` listeners attached from test B's zone,
  /// silently hanging any later test that touches the cached value (found
  /// the hard way -- see `test/lettering_desktop_test.dart`'s history).
  /// `EditorController.languageRegistry` already caches per-instance, which
  /// is what actually matters (avoids re-reading the asset on every widget
  /// rebuild); re-reading a small bundled JSON file once per *document
  /// session* is not a real cost worth this kind of cross-test landmine.
  static Future<LanguageRegistry> load({
    String assetPath = 'assets/languages.json',
  }) async {
    // Avoid sharing CachingAssetBundle's Future across test/application zones;
    // EditorController already caches the parsed registry per document session.
    final jsonString = await rootBundle.loadString(assetPath, cache: false);
    return LanguageRegistry.fromJson(jsonString);
  }

  factory LanguageRegistry.fromJson(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final entries = decoded['languages'] as List;
    final languages = [
      for (final entry in entries)
        LanguageInfo(
          code: (entry as Map<String, dynamic>)['code'] as String,
          name: entry['name'] as String,
          nativeName: entry['nativeName'] as String,
          active: entry['active'] as bool? ?? true,
        ),
    ];
    if (languages.length < 3 ||
        languages[0].code != 'en' ||
        languages[1].code != 'ru' ||
        languages[2].code != 'hi') {
      throw const FormatException('Language slots 0/1/2 must remain en/ru/hi');
    }
    return LanguageRegistry._(languages);
  }

  /// Slot index for [code] (Images[] position), or null if unknown.
  int? indexFor(String code) => _indexByCode[code];

  /// Language code at Images[] slot [index], or null if out of range.
  String? codeFor(int index) =>
      index >= 0 && index < languages.length ? languages[index].code : null;

  bool isKnown(String code) => _indexByCode.containsKey(code);
}

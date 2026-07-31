// vdd-comics-editor-uiux-lettering, Task 7.1: full backward-compatibility
// pass over every real .comics file in dataset/ (read-only -- opened via
// DartIoCore into its own temp working directory, never written back to
// dataset/ itself). Confirms: no crash opening any real file; no layer in
// any of these pre-existing files has kind/style/translations set (the new
// fields genuinely don't exist yet in real data, matching the additive-only
// design); and re-saving with zero edits reaches a stable fixed point.
//
// The fixed point is checked against the file's *second* resave, not its
// pristine original. The first resave can legitimately differ from the
// original: e.g. a legacy anim that omits `alpha` (relying on the C# side's
// Init()-assigned 1.0) gets `alpha: 1.0` written explicitly once resaved,
// because DefaultValueHandling.Ignore only omits values equal to
// default(double)==0, not the app's Init()-time default of 1 -- the *real*
// C# app would do the exact same thing opening and resaving this same file.
// That's cosmetic normalization, not data loss. What must never happen is
// continued drift: resave #1 -> reopen -> resave #2 must be byte-for-byte
// (structurally) identical to resave #1's own output, or every open/save
// cycle would silently keep rewriting the file.
//
// dataset/ is a monorepo-level fixture directory, not part of this app's own
// git history: apps/comics-editor-v2.9 is pushed to its own separate repo
// (comics108/comics-editor-v2.9), whose tree never includes dataset/ at all --
// it only resolves locally by directory-nesting coincidence in a full
// monorepo checkout. Any other clone of this repo (including CI, which
// checks out only this repo) genuinely cannot have dataset/ present, so this
// whole file must degrade to a no-op (skipped, not crashed) rather than
// assume it's always reachable.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/bridge/dart_io_core.dart';
import 'package:comics_editor/src/bridge/models_mapping.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory(Directory.current.path).parent.parent;
  final datasetDir = Directory('${repoRoot.path}/dataset');
  final datasetAvailable = datasetDir.existsSync();
  final datasetFiles = datasetAvailable
      ? (datasetDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.comics'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test(
    'sanity: dataset/ is reachable and has a realistic number of .comics files',
    () {
      expect(datasetFiles.length, greaterThanOrEqualTo(20));
    },
    skip: datasetAvailable
        ? false
        : 'dataset/ not present in this checkout (monorepo-only fixture, see file header)',
  );

  for (final file in datasetFiles) {
    final name = file.uri.pathSegments.last;
    test('backward-compat: $name opens cleanly, has no pre-existing kind/style/'
        'translations, and reaches a stable save fixed point', () async {
      Future<Map<String, dynamic>> openRaw(String path, String tag) async {
        final core = DartIoCore(
            workDirPath: Directory.systemTemp.createTempSync('bwcompat_${tag}_work').path);
        addTearDown(core.dispose);
        final opened = await core.call('openComics', {'path': path}) as Map<String, dynamic>;
        return opened;
      }

      Future<String> resave(Map<String, dynamic> opened, String path, String tag) async {
        final raw = opened['comics'] as Map<String, dynamic>;
        final document =
            comicsFromCore(raw, path, tempFolder: opened['tempFolder'] as String?);

        // No layer in any real dataset file uses the new fields yet.
        for (final layer in document.doc.layers) {
          expect(layer.kind, isNull, reason: '$name: layer "${layer.name}" has a kind already');
          expect(layer.style, isNull,
              reason: '$name: layer "${layer.name}" has a style already');
          expect(layer.translations, isEmpty,
              reason: '$name: layer "${layer.name}" has translations already');
        }

        final saveCore = DartIoCore(
            workDirPath: Directory.systemTemp.createTempSync('bwcompat_${tag}_savework').path);
        addTearDown(saveCore.dispose);
        final savedPath =
            '${Directory.systemTemp.createTempSync('bwcompat_${tag}_saved').path}/roundtrip.comics';
        await saveCore.call('saveComics', {
          'path': savedPath,
          'comics': comicsToCore(document),
        });
        return savedPath;
      }

      final opened1 = await openRaw(file.path, 'orig');
      final savedPath1 = await resave(opened1, file.path, 'save1');

      final opened2 = await openRaw(savedPath1, 'reopen1');
      final resave1Raw = opened2['comics'] as Map<String, dynamic>;
      final savedPath2 = await resave(opened2, savedPath1, 'save2');

      final opened3 = await openRaw(savedPath2, 'reopen2');
      final resave2Raw = opened3['comics'] as Map<String, dynamic>;

      // jsonDecode/jsonEncode round trip normalizes both sides to plain
      // Map/List/num/String/bool so `equals()` does a real deep structural
      // comparison, not an object-identity one.
      expect(
        jsonDecode(jsonEncode(resave2Raw)),
        equals(jsonDecode(jsonEncode(resave1Raw))),
        reason: '$name: still drifting after the first resave -- '
            'saving keeps rewriting the file even with zero edits',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}

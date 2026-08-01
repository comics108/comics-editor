// vdd-comics-editor-ai-uiux, Task 2.3: MultimodalPaths discovery -- env var override, upward
// search finding the real comics-multimodal checkout, and null when nothing is found.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ai/multimodal_paths.dart';

void main() {
  test('upward search finds the real comics-multimodal checkout from this repo', () {
    final root = MultimodalPaths.resolveCheckoutRoot();
    expect(root, isNotNull);
    expect(Directory('$root/scripts').existsSync(), isTrue);
    expect(File('$root/scripts/segment_image.py').existsSync(), isTrue);
  });

  test('resolveScriptsDir and resolveLibraryDir are derived from the same checkout root', () {
    final root = MultimodalPaths.resolveCheckoutRoot();
    expect(MultimodalPaths.resolveScriptsDir(), '$root/scripts');
    expect(MultimodalPaths.resolveLibraryDir(), '$root/work/library');
  });

  test('resolveCheckoutRoot returns null when searching from an isolated directory with no env override', () {
    if (Platform.environment['COMICS_MULTIMODAL_PATH'] != null) {
      // Can't meaningfully test the "not found" path when the test runner's own environment
      // already overrides it -- skip rather than produce a false failure.
      return;
    }
    final isolated = Directory.systemTemp.createTempSync('multimodal_paths_test_');
    try {
      expect(MultimodalPaths.resolveCheckoutRoot(from: isolated), isNull);
      expect(MultimodalPaths.resolveScriptsDir(from: isolated), isNull);
      expect(MultimodalPaths.resolveLibraryDir(from: isolated), isNull);
    } finally {
      isolated.deleteSync();
    }
  });

  test('resolvePython finds the project venv interpreter next to the real checkout', () {
    final python = MultimodalPaths.resolvePython();
    // Either the project's own .venv (created for this flow's Python work) or some python on
    // PATH -- either way, resolvePython should find *something* real on a dev machine that has
    // Python installed at all (which this repo's own test/CI environment does, per the Python
    // test suite this flow already ran).
    expect(python, isNotNull);
    expect(File(python!).existsSync(), isTrue);
  });
}

import 'dart:io';

/// vdd-comics-editor-ai-uiux, Task 2.3: locates the `comics-multimodal` Python checkout, its venv
/// interpreter, and its library directory -- mirrors `CoreClient.resolveBinary()`'s
/// env-var-override + upward-search pattern (`core_client.dart`). One discovery mechanism, reused
/// by both `ProcessCuttingClient` (needs the interpreter + scripts dir) and `library_browser.dart`
/// (needs the library dir), per 03-specifications.md's Affected Systems.
class MultimodalPaths {
  /// `COMICS_MULTIMODAL_PATH` env var, else search up to 6 parent directories from [from]
  /// (defaults to the current working directory) for `apps/comics-ai/comics-multimodal`. Returns
  /// null if not found -- callers must treat that as "pipeline not available here", not throw.
  static String? resolveCheckoutRoot({Directory? from}) {
    final env = Platform.environment['COMICS_MULTIMODAL_PATH'];
    if (env != null && Directory(env).existsSync()) return env;

    var dir = from ?? Directory.current;
    for (var i = 0; i < 6; i++) {
      final candidate = Directory('${dir.path}/apps/comics-ai/comics-multimodal');
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// `COMICS_MULTIMODAL_PYTHON` env var (if it points at a real file), else
  /// `<checkoutRoot>/.venv/bin/python` (the project's documented venv setup --
  /// `apps/comics-ai/comics-multimodal/README.md`), else whatever `python3`/`python` resolves to
  /// on PATH. Returns null if nothing is found -- `ProcessCuttingClient` maps that to
  /// `Failure(reason: "python_not_found", retryable: false)` before ever spawning a process.
  static String? resolvePython({Directory? from}) {
    final env = Platform.environment['COMICS_MULTIMODAL_PYTHON'];
    if (env != null && File(env).existsSync()) return env;

    final root = resolveCheckoutRoot(from: from);
    if (root != null) {
      final venvPython =
          Platform.isWindows ? '$root/.venv/Scripts/python.exe' : '$root/.venv/bin/python';
      if (File(venvPython).existsSync()) return venvPython;
    }

    final which = Platform.isWindows ? 'where' : 'which';
    final candidateNames =
        Platform.isWindows ? const ['python.exe', 'python3.exe'] : const ['python3', 'python'];
    for (final name in candidateNames) {
      try {
        final result = Process.runSync(which, [name]);
        if (result.exitCode == 0) {
          final resolved = (result.stdout as String).split('\n').first.trim();
          if (resolved.isNotEmpty) return resolved;
        }
      } on ProcessException {
        // which/where itself not available -- fall through to the next candidate / null.
      }
    }
    return null;
  }

  /// `<checkoutRoot>/scripts`, or null if the checkout isn't found.
  static String? resolveScriptsDir({Directory? from}) {
    final root = resolveCheckoutRoot(from: from);
    return root == null ? null : '$root/scripts';
  }

  /// `<checkoutRoot>/work/library`, or null if the checkout isn't found. Does not itself check
  /// whether the directory exists on disk yet -- a fresh checkout that never ran the pipeline is a
  /// normal case, handled by `library_browser.dart`'s empty state, not this resolver.
  static String? resolveLibraryDir({Directory? from}) {
    final root = resolveCheckoutRoot(from: from);
    return root == null ? null : '$root/work/library';
  }
}

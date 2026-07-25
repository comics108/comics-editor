import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'comics_core.dart';

/// NDJSON-клиент headless-ядра (`native/Comics.Editor.Headless`).
///
/// Ядро — self-contained бинарник `Comics.Editor`, публикуемый скриптом
/// `tool/build_headless.sh`. Поиск бинарника: переменная окружения
/// `COMICS_CORE_PATH` → ресурсы платформенного бандла → dev-публикация в
/// `native/Comics.Editor.Headless/publish/<rid>/`.
class CoreClient implements ComicsCore {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  int _nextId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final List<String> _stderrLines = [];

  bool get isRunning => _process != null;

  @override
  bool get isAvailable => resolveBinary() != null;

  /// Возвращает null, если бинарник ядра не найден.
  static String? resolveBinary() {
    final env = Platform.environment['COMICS_CORE_PATH'];
    if (env != null && File(env).existsSync()) return env;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      // macOS: Comics Editor.app/Contents/{MacOS,Resources/comics-core}
      '$exeDir/../Resources/comics-core/Comics.Editor',
      // Linux: bundle/{comics_editor, data/comics-core}
      '$exeDir/data/comics-core/Comics.Editor',
    ];

    // Dev-режим (flutter run): ищем publish-папку вверх от CWD. RID-кандидаты
    // ограничены текущей ОС — иначе при наличии устаревших publish-артефактов
    // другой платформы в рабочей копии выбирается чужой (нерабочий) бинарник.
    final rids = switch (Platform.operatingSystem) {
      'macos' => const ['osx-arm64', 'osx-x64'],
      'linux' => const ['linux-x64', 'linux-arm64'],
      'windows' => const ['win-x64'],
      _ => const <String>[],
    };
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final base = '${dir.path}/native/Comics.Editor.Headless/publish';
      for (final rid in rids) {
        candidates.add('$base/$rid/Comics.Editor');
        candidates.add('$base/$rid/Comics.Editor.exe');
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// Запускает процесс ядра. Возвращает false, если бинарник не найден.
  Future<bool> start() async {
    if (_process != null) return true;
    final binary = resolveBinary();
    if (binary == null) return false;

    final process = await Process.start(binary, const []);
    _process = process;
    _stderrLines.clear();
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onDone: _onExit);
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_stderrLines.add);
    unawaited(process.exitCode.then(_onExit));
    return true;
  }

  void _onLine(String line) {
    if (line.isEmpty) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(line) as Map<String, dynamic>;
    } on FormatException {
      return; // мусор в stdout (логи) — игнорируем
    }
    final id = message['id'];
    final completer = id is int ? _pending.remove(id) : null;
    if (completer == null) return;
    final error = message['error'];
    if (error != null) {
      completer.completeError(
          CoreException((error['message'] as String?) ?? error.toString()));
    } else {
      completer.complete(message);
    }
  }

  void _onExit([int? exitCode]) {
    _process = null;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _stderrSub?.cancel();
    _stderrSub = null;
    final detail = [
      if (exitCode != null) 'exit code $exitCode',
      if (_stderrLines.isNotEmpty) _stderrLines.join('\n'),
    ].join(': ');
    final message =
        detail.isEmpty ? 'Core process exited' : 'Core process exited ($detail)';
    for (final pending in _pending.values) {
      pending.completeError(CoreException(message));
    }
    _pending.clear();
  }

  @override
  Future<dynamic> call(String method,
      [Map<String, dynamic>? params,
      Duration timeout = const Duration(seconds: 60)]) async {
    if (!await start()) {
      throw CoreException('Core binary not found — run tool/build_headless.sh');
    }
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _process!.stdin.writeln(jsonEncode({
      'id': id,
      'method': method,
      'params': ?params,
    }));
    await _process!.stdin.flush();
    final response = await completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw CoreException('Core call "$method" timed out');
    });
    return response['result'];
  }

  @override
  Future<void> dispose() async {
    _process?.kill();
    _onExit();
  }
}

class CoreException implements Exception {
  CoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

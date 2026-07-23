import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:path_provider/path_provider.dart';

import 'comics_core.dart';
import 'core_client.dart' show CoreException;

typedef _ComicsCallNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ComicsFreeNative = Void Function(Pointer<Utf8>);
typedef _ComicsFree = void Function(Pointer<Utf8>);
typedef _ComicsSetEnvNative = Void Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ComicsSetEnv = void Function(Pointer<Utf8>, Pointer<Utf8>);

/// FFI-транспорт ядра: NativeAOT-библиотека `Comics.Editor.Native`
/// (`comics_call`/`comics_free`). Используется на iOS/Android; на десктопе —
/// только в тестах (osx-dylib), путь задаётся [overrideLibraryPath] или
/// переменной окружения `COMICS_CORE_LIB`.
class FfiCore implements ComicsCore {
  FfiCore({Map<String, String> environment = const {}})
      : _environment = environment;

  /// Для тестов: явный путь к библиотеке.
  static String? overrideLibraryPath;

  /// Переменные окружения, выставляемые в ядре до первого вызова
  /// (HOME/XDG_DATA_HOME для песочницы — Task 3.5).
  final Map<String, String> _environment;
  bool _envApplied = false;

  static String? resolveLibrary() {
    final override = overrideLibraryPath ?? Platform.environment['COMICS_CORE_LIB'];
    if (override != null) return File(override).existsSync() ? override : null;
    if (Platform.isIOS) return ''; // статическая линковка → DynamicLibrary.process()
    if (Platform.isAndroid) return 'libcomicscore.so';
    // desktop (тесты): dev-публикация
    for (final rid in const ['osx-arm64', 'osx-x64', 'linux-x64']) {
      final path =
          '${Directory.current.path}/native/Comics.Editor.Native/publish/$rid/Comics.Editor.dylib';
      if (File(path).existsSync()) return path;
      final so = path.replaceAll('.dylib', '.so');
      if (File(so).existsSync()) return so;
    }
    return null;
  }

  static DynamicLibrary _open(String resolved) => resolved.isEmpty
      ? DynamicLibrary.process()
      : DynamicLibrary.open(resolved);

  @override
  bool get isAvailable => resolveLibrary() != null;

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final resolved = resolveLibrary();
    if (resolved == null) {
      throw CoreException('Native core library not found — run tool/build_native.sh');
    }
    var env = _envApplied ? const <String, String>{} : _environment;
    // Task 3.5: на мобильных TempFolder ядра (LocalApplicationData → $HOME)
    // должен попасть в песочницу приложения.
    if (!_envApplied &&
        env.isEmpty &&
        (Platform.isIOS || Platform.isAndroid)) {
      final support = await getApplicationSupportDirectory();
      env = {
        'HOME': support.path,
        'XDG_DATA_HOME': '${support.path}/.local/share',
      };
    }
    _envApplied = true;
    final paramsJson = params == null ? null : jsonEncode(params);

    // Синхронный C-вызов уводим с UI-потока.
    final responseJson = await Isolate.run(() {
      final lib = _open(resolved);
      final comicsCall = lib
          .lookupFunction<_ComicsCallNative, _ComicsCallNative>('comics_call');
      final comicsFree =
          lib.lookupFunction<_ComicsFreeNative, _ComicsFree>('comics_free');

      if (env.isNotEmpty) {
        final setEnv = lib
            .lookupFunction<_ComicsSetEnvNative, _ComicsSetEnv>('comics_set_env');
        env.forEach((name, value) {
          final namePtr = name.toNativeUtf8();
          final valuePtr = value.toNativeUtf8();
          setEnv(namePtr, valuePtr);
          calloc.free(namePtr);
          calloc.free(valuePtr);
        });
      }

      final methodPtr = method.toNativeUtf8();
      final paramsPtr = paramsJson?.toNativeUtf8() ?? Pointer<Utf8>.fromAddress(0);
      try {
        final resultPtr = comicsCall(methodPtr, paramsPtr);
        if (resultPtr.address == 0) return null;
        final json = resultPtr.toDartString();
        comicsFree(resultPtr);
        return json;
      } finally {
        calloc.free(methodPtr);
        if (paramsPtr.address != 0) calloc.free(paramsPtr);
      }
    });

    if (responseJson == null) {
      throw CoreException('Native core call failed (null response)');
    }
    final response = jsonDecode(responseJson) as Map<String, dynamic>;
    final error = response['error'];
    if (error != null) {
      throw CoreException((error['message'] as String?) ?? error.toString());
    }
    return response['result'];
  }

  @override
  Future<void> dispose() async {}
}

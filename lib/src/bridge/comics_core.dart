import 'dart:io';

import 'core_client.dart';
import 'ffi_core.dart';

/// Транспорт-абстракция ядра (протокол один: method + JSON-параметры → JSON):
/// - desktop: [CoreClient] — self-contained процесс Comics.Editor.Headless (NDJSON/stdio);
/// - iOS/Android: [FfiCore] — NativeAOT-библиотека Comics.Editor.Native (dart:ffi).
abstract interface class ComicsCore {
  /// Доступно ли ядро на этой машине (бинарник/библиотека находится).
  bool get isAvailable;

  Future<dynamic> call(String method, [Map<String, dynamic>? params]);

  Future<void> dispose();
}

ComicsCore createComicsCore() {
  if (Platform.isIOS || Platform.isAndroid) return FfiCore();
  return CoreClient();
}

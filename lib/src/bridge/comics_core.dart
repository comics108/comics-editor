import 'dart:io';

import 'core_client.dart';
import 'dart_io_core.dart';
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
  // iOS: CoreCLR NativeAOT не публикуется для ios-arm64 в .NET 10 — решение
  // пользователя (2026-07-23) — Dart-I/O fallback (см. dart_io_core.dart).
  // Android: NativeAOT+FFI, как утверждено в спецификации.
  if (Platform.isIOS) return DartIoCore();
  if (Platform.isAndroid) return FfiCore();
  return CoreClient();
}

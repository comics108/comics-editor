import 'dart:io';

import 'core_client.dart';
import 'dart_io_core.dart';

/// Транспорт-абстракция ядра (протокол один: method + JSON-параметры → JSON):
/// - desktop: [CoreClient] — self-contained процесс Comics.Editor.Headless (NDJSON/stdio);
/// - iOS/Android: [DartIoCore] — Dart-I/O fallback (package:archive), без внешних бинарников.
abstract interface class ComicsCore {
  /// Доступно ли ядро на этой машине (бинарник/библиотека находится).
  bool get isAvailable;

  Future<dynamic> call(String method, [Map<String, dynamic>? params]);

  Future<void> dispose();
}

ComicsCore createComicsCore() {
  // iOS и Android: CoreCLR NativeAOT (ILCompiler) не поддерживает ни ios-arm64,
  // ни linux-bionic-*/android-* в .NET 10 — оба .NET-мобильных таргета built на
  // Mono, не CoreCLR, и явно исключены из NativeAOT runtime pack SDK
  // (Microsoft.NETCoreSdk.BundledVersions.props: RuntimePackExcludedRuntimeIdentifiers
  // ="android;linux-bionic"). Решение пользователя (2026-07-23/2026-07-25) — на обеих
  // мобильных платформах Dart-I/O fallback (см. dart_io_core.dart), FfiCore/
  // Comics.Editor.Native больше не используются нигде — оставлены как задел на случай,
  // если Microsoft добавит публичную поддержку ILCompiler для мобильных RID.
  if (Platform.isIOS || Platform.isAndroid) return DartIoCore();
  return CoreClient();
}

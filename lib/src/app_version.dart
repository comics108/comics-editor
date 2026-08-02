import 'package:package_info_plus/package_info_plus.dart';

/// The app's version, read from `pubspec.yaml` at build time (via
/// `package_info_plus`, which surfaces the platform-generated app metadata
/// derived from `pubspec.yaml`'s `version:` field). Loaded once during
/// startup ([load]) before `runApp`, so UI can read [current] synchronously
/// without a loading flicker.
///
/// [fallback] mirrors `pubspec.yaml`'s `version:` and is used only if
/// [load] hasn't run yet (e.g. in a widget test that pumps a widget without
/// going through `main()`) -- keep it in sync by hand when bumping the real
/// version, since a test environment can't read the pubspec file directly.
class AppVersion {
  AppVersion._();

  static const String fallback = '3.2.0';

  static String _current = fallback;

  /// The current app version, e.g. "3.1.0". Safe to read synchronously
  /// anywhere after [load] has completed.
  static String get current => _current;

  /// Fetches the real version from platform package info. Call once, before
  /// `runApp`.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _current = info.version;
    } catch (_) {
      // Platform metadata unavailable (e.g. some test/CI environments) --
      // keep the fallback rather than crash startup over a version label.
    }
  }
}

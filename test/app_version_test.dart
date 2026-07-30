import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/app_version.dart';

void main() {
  test("fallback matches pubspec.yaml's version exactly", () {
    // Guards against AppVersion.fallback silently drifting from the real
    // pubspec.yaml version -- reads the pubspec directly rather than hardcoding
    // an expected string here too, so this fails loudly (not silently shows a
    // stale fallback) if someone bumps one and forgets the other.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([\d.]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'could not find version: in pubspec.yaml');
    expect(AppVersion.fallback, match!.group(1));
  });

  test('current defaults to fallback before load() has run', () {
    expect(AppVersion.current, AppVersion.fallback);
  });

  test('load() does not throw even without full platform plugin registration',
      () async {
    await AppVersion.load();
    expect(AppVersion.current, isNotEmpty);
  });
}

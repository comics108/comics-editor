import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android advertises only the dedicated Comics MIME type', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('application/vnd.nativemind.comics'));
    expect(manifest, isNot(contains('android:mimeType="*/*"')));
    expect(manifest, isNot(contains('android:pathPattern=".*\\\\.puzzle"')));
  });

  test('Apple bundles advertise only the Comics document type', () {
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final macos = File('macos/Runner/Info.plist').readAsStringSync();

    for (final plist in <String>[ios, macos]) {
      expect(plist, contains('net.nativemind.comics'));
      expect(plist, contains('<string>comics</string>'));
      expect(plist, contains('<string>Alternate</string>'));
      expect(plist, isNot(contains('net.nativemind.puzzle')));
    }
  });

  test('Windows registration is current-user, quoted, and non-defaulting', () {
    final register = File(
      'windows/packaging/Register-ComicsFileAssociation.ps1',
    ).readAsStringSync();
    final unregister = File(
      'windows/packaging/Unregister-ComicsFileAssociation.ps1',
    ).readAsStringSync();

    expect(register, contains('HKCU:\\Software\\Classes'));
    expect(register, contains('NativeMind.ComicsEditor.comics'));
    expect(register, contains('OpenWithProgids'));
    expect(register, contains('RegisteredApplications'));
    expect(register, contains('`"%1`"'));
    expect(register, contains(r'$WhatIf'));
    expect(register, isNot(contains('HKLM:')));
    expect(register, isNot(contains('UserChoice')));
    expect(unregister, contains('NativeMind.ComicsEditor.comics'));
  });

  test('Linux metadata is dedicated and does not force a default', () {
    final mime = File(
      'linux/packaging/net.nativemind.comics.editor.xml',
    ).readAsStringSync();
    final desktop = File(
      'linux/packaging/net.nativemind.comics.editor.desktop.in',
    ).readAsStringSync();
    final install = File('linux/packaging/install-user.sh').readAsStringSync();
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();

    expect(mime, contains('application/vnd.nativemind.comics'));
    expect(mime, contains('pattern="*.comics"'));
    expect(desktop, contains('Exec="@EXECUTABLE@" %f'));
    expect(desktop, contains('MimeType=application/vnd.nativemind.comics;'));
    expect('%f'.allMatches(desktop), hasLength(1));
    expect(install, isNot(contains('xdg-mime default')));
    expect(cmake, contains('APPLICATION_ID "net.nativemind.comics.editor"'));
  });
}

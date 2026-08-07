// tdd-dot-comics-format, Plan Task 4.3: colorToHex/colorFromHex back the
// solid-color layer picker -- pure conversion helpers, tested directly.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/widgets/dialogs.dart';

void main() {
  test('colorToHex renders an opaque color as #RRGGBB', () {
    expect(colorToHex(const Color(0xFFFFFFFF)), '#ffffff');
    expect(colorToHex(const Color(0xFF000000)), '#000000');
  });

  test('colorFromHex parses #RRGGBB as opaque', () {
    final color = colorFromHex('#ffffff')!;
    expect(color.toARGB32(), 0xFFFFFFFF);
  });

  test('colorFromHex parses without a leading #', () {
    final color = colorFromHex('ffffff')!;
    expect(color.toARGB32(), 0xFFFFFFFF);
  });

  test('colorFromHex returns null for an invalid string', () {
    expect(colorFromHex('not-a-color'), isNull);
    expect(colorFromHex('#fff'), isNull);
  });

  test('colorToHex/colorFromHex round-trip', () {
    const original = Color(0xFF57422D);
    final roundTripped = colorFromHex(colorToHex(original))!;
    expect(roundTripped.toARGB32(), original.toARGB32());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/widgets/confidence_badge.dart';

void main() {
  test('colorsFor picks high/medium/low buckets at the documented thresholds', () {
    expect(ConfidenceBadge.colorsFor(0.92).$1, const Color(0xFFE3F2E6));
    expect(ConfidenceBadge.colorsFor(0.85).$1, const Color(0xFFE3F2E6)); // boundary: high
    expect(ConfidenceBadge.colorsFor(0.84).$1, const Color(0xFFF7ECD4)); // boundary: medium
    expect(ConfidenceBadge.colorsFor(0.64).$1, const Color(0xFFF7ECD4));
    expect(ConfidenceBadge.colorsFor(0.50).$1, const Color(0xFFF7ECD4)); // boundary: medium
    expect(ConfidenceBadge.colorsFor(0.49).$1, const Color(0xFFFDE4DC)); // boundary: low
    expect(ConfidenceBadge.colorsFor(0.10).$1, const Color(0xFFFDE4DC));
  });
}

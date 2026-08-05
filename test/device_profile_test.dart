import 'package:comics_editor/src/ui/device_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target profiles expose stable dimensions and vertical screenfuls', () {
    expect(DeviceProfile.iPad.dimensionsLabel, '768 × 1024');
    expect(DeviceProfile.iPad.verticalViewportHeight(1080), 1440);

    expect(DeviceProfile.iPhone.dimensionsLabel, '390 × 844');
    expect(
      DeviceProfile.iPhone.verticalViewportHeight(1080),
      closeTo(2337.23, .01),
    );
  });
}

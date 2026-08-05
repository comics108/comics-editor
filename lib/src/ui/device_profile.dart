/// A target reader viewport used for authoring guides.
///
/// Profiles are application UI state: they are independent of the computer or
/// phone running the editor and are not serialized into `.comics` files.
class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
  });

  final String id;
  final String label;
  final int width;
  final int height;

  double get aspectRatio => height / width;

  /// Document-space height visible on this device when a vertical comic is
  /// scaled to the device width.
  double verticalViewportHeight(double documentWidth) =>
      documentWidth * aspectRatio;

  String get dimensionsLabel => '$width × $height';

  static const iPad = DeviceProfile(
    id: 'ipad',
    label: 'iPad',
    width: 768,
    height: 1024,
  );

  static const iPhone = DeviceProfile(
    id: 'iphone',
    label: 'iPhone',
    width: 390,
    height: 844,
  );

  static const all = <DeviceProfile>[iPad, iPhone];
}

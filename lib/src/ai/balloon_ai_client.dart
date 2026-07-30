import 'dart:typed_data';

/// vdd-comics-editor-uiux-lettering: client-side contract for AI balloon
/// text-to-artwork generation. CLIENT CONTRACT ONLY -- no on-device engine,
/// no server, no hardware-capability detection is built in this flow (see
/// `03-specifications.md`'s Dependencies/Non-Goals). [StubBalloonAiClient]
/// (`stub_balloon_ai_client.dart`) is what every later UI task in this flow
/// builds and tests against; a real engine-backed implementation is out of
/// scope here.
abstract class BalloonAiClient {
  Stream<GenerationEvent> generate({
    required Uint8List sourceBalloonPng,
    required String targetText,
    required String targetLangCode, // any registry code, not just en/ru/hi
    required bool isHandLettered, // caller shouldn't offer this; defense-in-depth
  });
}

sealed class GenerationEvent {
  const GenerationEvent();
}

/// First event: whether generation is running on-device or was routed to a
/// server. Per the approved design reference, [reason] should be a
/// plain-language explanation when routed to the cloud (e.g. "This device
/// can't render Hindi shaping locally — sent to the server"), not just an
/// on-device/cloud label.
class RoutingDecided extends GenerationEvent {
  const RoutingDecided({required this.onDevice, this.reason});
  final bool onDevice;
  final String? reason;
}

class Progress extends GenerationEvent {
  const Progress({required this.stage});
  final String stage;
}

class Success extends GenerationEvent {
  const Success({required this.pngBytes, required this.width, required this.height});
  final Uint8List pngBytes;
  final int width;
  final int height;
}

/// [reason] is a stable code (`"text_overflow"`, `"render_error"`,
/// `"network_required"`, `"hand_lettered"`, ...), not a display string --
/// the UI maps it to copy + retry affordance per `02-visual.md`'s failure
/// card state.
class Failure extends GenerationEvent {
  const Failure({required this.reason, required this.retryable});
  final String reason;
  final bool retryable;
}

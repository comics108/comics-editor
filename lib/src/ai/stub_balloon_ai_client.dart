import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'balloon_ai_client.dart';

/// What [StubBalloonAiClient.generate] resolves to -- lets a test or manual
/// walkthrough force every state `02-visual.md`'s balloon editor card
/// defines (generating, success, the various failure copies) without a real
/// engine.
enum StubGenerationOutcome { success, textOverflow, renderError, networkRequired }

/// vdd-comics-editor-uiux-lettering, Task 4.1: deterministic fake
/// [BalloonAiClient]. No randomness -- [outcome] is set explicitly by the
/// caller, and [Success]'s placeholder artwork is derived deterministically
/// from the request (same text+language always produces the same pixels),
/// so repeated manual walkthroughs and tests are reproducible.
class StubBalloonAiClient implements BalloonAiClient {
  StubBalloonAiClient({
    this.outcome = StubGenerationOutcome.success,
    this.onDevice = true,
    this.routingReason,
    this.stepDelay = const Duration(milliseconds: 1),
  });

  StubGenerationOutcome outcome;
  bool onDevice;
  String? routingReason;
  Duration stepDelay;

  @override
  Stream<GenerationEvent> generate({
    required Uint8List sourceBalloonPng,
    required String targetText,
    required String targetLangCode,
    required bool isHandLettered,
  }) async* {
    // Defense-in-depth per Specifications: the UI should never offer
    // Generate for a hand-lettered balloon (button disabled), but the
    // client rejects it too in case that invariant is ever violated.
    if (isHandLettered) {
      yield const Failure(reason: 'hand_lettered', retryable: false);
      return;
    }

    yield RoutingDecided(onDevice: onDevice, reason: routingReason);
    await Future.delayed(stepDelay);
    yield const Progress(stage: 'rendering');
    await Future.delayed(stepDelay);

    switch (outcome) {
      case StubGenerationOutcome.success:
        final placeholder = _placeholderFor(sourceBalloonPng, targetText, targetLangCode);
        yield Success(
            pngBytes: placeholder.bytes, width: placeholder.width, height: placeholder.height);
      case StubGenerationOutcome.textOverflow:
        yield const Failure(reason: 'text_overflow', retryable: true);
      case StubGenerationOutcome.renderError:
        yield const Failure(reason: 'render_error', retryable: true);
      case StubGenerationOutcome.networkRequired:
        yield const Failure(reason: 'network_required', retryable: true);
    }
  }

  _Placeholder _placeholderFor(
      Uint8List sourceBalloonPng, String targetText, String targetLangCode) {
    final decodedSource = img.decodeImage(sourceBalloonPng);
    final width = decodedSource?.width ?? 256;
    final height = decodedSource?.height ?? 128;
    var seed = 0;
    for (final unit in '$targetText|$targetLangCode'.codeUnits) {
      seed = (seed * 31 + unit) & 0xFFFFFF;
    }
    final placeholder = img.Image(width: width, height: height);
    img.fill(placeholder,
        color: img.ColorRgba8((seed >> 16) & 0xFF, (seed >> 8) & 0xFF, seed & 0xFF, 255));
    return _Placeholder(Uint8List.fromList(img.encodePng(placeholder)), width, height);
  }
}

class _Placeholder {
  _Placeholder(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

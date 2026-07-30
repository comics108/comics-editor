// vdd-comics-editor-uiux-lettering, Task 4.1: StubBalloonAiClient emits the
// expected GenerationEvent sequence for each outcome the balloon editor
// card (Task 4.2) will need to render -- success, each failure reason, and
// the hand-lettered defense-in-depth rejection.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/balloon_ai_client.dart';
import 'package:comics_editor/src/ai/stub_balloon_ai_client.dart';

Uint8List _samplePng([int width = 100, int height = 50]) {
  final image = img.Image(width: width, height: height);
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('success path: RoutingDecided, Progress, then Success with real png bytes', () async {
    final client = StubBalloonAiClient(stepDelay: Duration.zero);
    final events = await client
        .generate(
          sourceBalloonPng: _samplePng(200, 100),
          targetText: 'Hello',
          targetLangCode: 'en',
          isHandLettered: false,
        )
        .toList();

    expect(events.length, 3);
    expect(events[0], isA<RoutingDecided>());
    expect(events[1], isA<Progress>());
    final success = events[2] as Success;
    expect(success.width, 200);
    expect(success.height, 100);
    expect(img.decodeImage(success.pngBytes), isNotNull); // real, decodable PNG
  });

  test('routing carries onDevice + a plain-language reason when set', () async {
    final client = StubBalloonAiClient(
      stepDelay: Duration.zero,
      onDevice: false,
      routingReason: "This device can't render Hindi shaping locally — sent to the server",
    );
    final events = await client
        .generate(
          sourceBalloonPng: _samplePng(),
          targetText: 'नमस्ते',
          targetLangCode: 'hi',
          isHandLettered: false,
        )
        .toList();

    final routing = events[0] as RoutingDecided;
    expect(routing.onDevice, isFalse);
    expect(routing.reason, contains('sent to the server'));
  });

  for (final entry in {
    StubGenerationOutcome.textOverflow: 'text_overflow',
    StubGenerationOutcome.renderError: 'render_error',
    StubGenerationOutcome.networkRequired: 'network_required',
  }.entries) {
    test('${entry.value} failure path: RoutingDecided, Progress, then retryable Failure',
        () async {
      final client = StubBalloonAiClient(outcome: entry.key, stepDelay: Duration.zero);
      final events = await client
          .generate(
            sourceBalloonPng: _samplePng(),
            targetText: 'x',
            targetLangCode: 'en',
            isHandLettered: false,
          )
          .toList();

      expect(events.length, 3);
      expect(events[0], isA<RoutingDecided>());
      expect(events[1], isA<Progress>());
      final failure = events[2] as Failure;
      expect(failure.reason, entry.value);
      expect(failure.retryable, isTrue);
    });
  }

  test('hand-lettered balloon is rejected immediately as defense-in-depth, no routing/progress',
      () async {
    final client = StubBalloonAiClient(stepDelay: Duration.zero);
    final events = await client
        .generate(
          sourceBalloonPng: _samplePng(),
          targetText: 'x',
          targetLangCode: 'en',
          isHandLettered: true,
        )
        .toList();

    expect(events.length, 1);
    final failure = events.single as Failure;
    expect(failure.reason, 'hand_lettered');
    expect(failure.retryable, isFalse);
  });

  test('success placeholder is deterministic: same text+lang always produces identical bytes',
      () async {
    final client = StubBalloonAiClient(stepDelay: Duration.zero);
    final source = _samplePng(120, 60);

    Future<Success> run() async {
      final events = await client
          .generate(
              sourceBalloonPng: source,
              targetText: 'Same text',
              targetLangCode: 'fr',
              isHandLettered: false)
          .toList();
      return events.last as Success;
    }

    final a = await run();
    final b = await run();
    expect(a.pngBytes, equals(b.pngBytes));
  });

  test('success placeholder differs for different text/language (visually distinguishable)',
      () async {
    final client = StubBalloonAiClient(stepDelay: Duration.zero);
    final source = _samplePng(120, 60);

    final enEvents = await client
        .generate(
            sourceBalloonPng: source, targetText: 'Hello', targetLangCode: 'en', isHandLettered: false)
        .toList();
    final frEvents = await client
        .generate(
            sourceBalloonPng: source, targetText: 'Bonjour', targetLangCode: 'fr', isHandLettered: false)
        .toList();

    final en = enEvents.last as Success;
    final fr = frEvents.last as Success;
    expect(en.pngBytes, isNot(equals(fr.pngBytes)));
  });
}

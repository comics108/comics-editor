// vdd-comics-editor-ai-uiux, Task 2.2: StubCuttingClient emits the expected CuttingEvent
// sequence for each outcome the Cutting mode UI (Phases 4-6) will need to render.
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/stub_cutting_client.dart';

Uint8List _samplePng() => Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 400)));

void main() {
  test('success path: RoutingDecided, 3x Progress, then Success with 4 canned regions', () async {
    final client = StubCuttingClient(stepDelay: Duration.zero);
    final events = await client.segment(sourceImageBytes: _samplePng()).toList();

    expect(events.length, 5);
    expect(events[0], isA<RoutingDecided>());
    expect(events[1], isA<Progress>());
    expect(events[2], isA<Progress>());
    expect(events[3], isA<Progress>());
    final success = events[4] as Success;
    expect(success.regions.length, 4);
    expect(success.regions.map((r) => r.kind).toSet(),
        {'background', 'character', 'balloon', 'art'});
    for (final region in success.regions) {
      expect(img.decodeImage(region.cropPng), isNotNull); // real, decodable PNG
      expect(region.confidence, inInclusiveRange(0.0, 1.0));
    }
  });

  test('routing carries onDevice + reason when set', () async {
    final client = StubCuttingClient(
      stepDelay: Duration.zero,
      onDevice: false,
      routingReason: 'forced for test',
    );
    final events = await client.segment(sourceImageBytes: _samplePng()).toList();
    final routing = events[0] as RoutingDecided;
    expect(routing.onDevice, isFalse);
    expect(routing.reason, 'forced for test');
  });

  for (final entry in {
    StubCuttingOutcome.modelCheckpointNotFound: ('model_checkpoint_not_found', false),
    StubCuttingOutcome.pythonNotFound: ('python_not_found', false),
    StubCuttingOutcome.processError: ('process_error', true),
  }.entries) {
    test('${entry.value.$1} failure path: RoutingDecided, 3x Progress, then Failure', () async {
      final client = StubCuttingClient(outcome: entry.key, stepDelay: Duration.zero);
      final events = await client.segment(sourceImageBytes: _samplePng()).toList();

      expect(events.length, 5);
      expect(events[0], isA<RoutingDecided>());
      final failure = events[4] as Failure;
      expect(failure.reason, entry.value.$1);
      expect(failure.retryable, entry.value.$2);
    });
  }

  test('custom regions override the default canned set', () async {
    final custom = [
      DetectedRegion(
        kind: 'character',
        confidence: 0.5,
        bbox: const Rect.fromLTWH(0, 0, 10, 10),
        cropPng: Uint8List(0),
      ),
    ];
    final client = StubCuttingClient(stepDelay: Duration.zero, regions: custom);
    final events = await client.segment(sourceImageBytes: _samplePng()).toList();
    final success = events.last as Success;
    expect(success.regions, same(custom));
  });
}

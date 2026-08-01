import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;
import 'package:image/image.dart' as img;

import 'cutting_client.dart';

/// What [StubCuttingClient.segment] resolves to -- lets a test or manual walkthrough force every
/// state `02-visual.md`'s Cutting mode defines without a real subprocess/model.
enum StubCuttingOutcome { success, modelCheckpointNotFound, pythonNotFound, processError }

/// vdd-comics-editor-ai-uiux, Task 2.2: deterministic fake [MultimodalCuttingClient], mirroring
/// `StubBalloonAiClient`'s shape. No randomness -- [outcome] is set explicitly by the caller, and
/// the default canned [regions] cover all four kinds so UI work (Phases 4-6) can be built and
/// manually walked through without waiting on the real `segment_image.py` subprocess
/// (`ProcessCuttingClient`, Task 2.4).
class StubCuttingClient implements MultimodalCuttingClient {
  StubCuttingClient({
    this.outcome = StubCuttingOutcome.success,
    this.onDevice = true,
    this.routingReason,
    this.stepDelay = const Duration(milliseconds: 1),
    List<DetectedRegion>? regions,
  }) : regions = regions ?? defaultRegions();

  StubCuttingOutcome outcome;
  bool onDevice;
  String? routingReason;
  Duration stepDelay;
  List<DetectedRegion> regions;

  @override
  Stream<CuttingEvent> segment({required Uint8List sourceImageBytes}) async* {
    yield RoutingDecided(onDevice: onDevice, reason: routingReason);
    await Future.delayed(stepDelay);
    yield const Progress(stage: 'loading_model');
    await Future.delayed(stepDelay);
    yield const Progress(stage: 'segmenting');
    await Future.delayed(stepDelay);
    yield const Progress(stage: 'extracting_regions');
    await Future.delayed(stepDelay);

    switch (outcome) {
      case StubCuttingOutcome.success:
        yield Success(regions: regions);
      case StubCuttingOutcome.modelCheckpointNotFound:
        yield const Failure(reason: 'model_checkpoint_not_found', retryable: false);
      case StubCuttingOutcome.pythonNotFound:
        yield const Failure(reason: 'python_not_found', retryable: false);
      case StubCuttingOutcome.processError:
        yield const Failure(reason: 'process_error', retryable: true);
    }
  }

  /// Four canned regions, one per kind, at distinct positions/confidences -- enough to exercise
  /// the region rail, canvas overlay, and review card's kind-conditional actions in a manual
  /// walkthrough without a real photo or model.
  static List<DetectedRegion> defaultRegions() => [
        _region(kind: 'background', bbox: const Rect.fromLTWH(0, 0, 300, 200), confidence: 0.96),
        _region(kind: 'character', bbox: const Rect.fromLTWH(20, 220, 90, 110), confidence: 0.92),
        _region(kind: 'balloon', bbox: const Rect.fromLTWH(140, 40, 70, 60), confidence: 0.99),
        _region(kind: 'art', bbox: const Rect.fromLTWH(10, 340, 280, 30), confidence: 0.64),
      ];

  static DetectedRegion _region({
    required String kind,
    required Rect bbox,
    required double confidence,
  }) {
    var seed = 0;
    for (final unit in kind.codeUnits) {
      seed = (seed * 31 + unit) & 0xFFFFFF;
    }
    final width = bbox.width.round().clamp(1, 4096);
    final height = bbox.height.round().clamp(1, 4096);
    final placeholder = img.Image(width: width, height: height);
    img.fill(placeholder,
        color: img.ColorRgba8((seed >> 16) & 0xFF, (seed >> 8) & 0xFF, seed & 0xFF, 255));
    return DetectedRegion(
      kind: kind,
      confidence: confidence,
      bbox: bbox,
      cropPng: Uint8List.fromList(img.encodePng(placeholder)),
    );
  }
}

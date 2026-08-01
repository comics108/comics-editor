import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;

/// vdd-comics-editor-ai-uiux: client-side contract for the multimodal cutting/segmentation
/// pipeline (`apps/comics-ai/comics-multimodal`). Mirrors `BalloonAiClient`'s shape
/// (`balloon_ai_client.dart`) deliberately, so corrector muscle memory transfers between the two
/// review workflows (see 03-specifications.md's Overview). [ProcessCuttingClient]
/// (`process_cutting_client.dart`) is the real desktop implementation, spawning
/// `segment_image.py`; [StubCuttingClient] (`stub_cutting_client.dart`) is what every UI task
/// builds and tests against.
abstract class MultimodalCuttingClient {
  Stream<CuttingEvent> segment({required Uint8List sourceImageBytes});
}

sealed class CuttingEvent {
  const CuttingEvent();
}

/// First event: whether segmentation is running on-device or was routed to a server. This
/// iteration always reports [onDevice] true -- there is no server path built (Requirements Won't
/// Have) -- but the event still fires so the UI's routing indicator has something to show and
/// doesn't need a distinct "no routing info" state.
class RoutingDecided extends CuttingEvent {
  const RoutingDecided({required this.onDevice, this.reason});
  final bool onDevice;
  final String? reason;
}

/// [stage] is a stable code ("loading_model", "segmenting", "extracting_regions"), matching
/// `segment_image.py`'s NDJSON `progress` events -- the UI maps it to display copy.
class Progress extends CuttingEvent {
  const Progress({required this.stage});
  final String stage;
}

class Success extends CuttingEvent {
  const Success({required this.regions});
  final List<DetectedRegion> regions;
}

/// [reason] is a stable code ("model_checkpoint_not_found", "image_not_readable",
/// "python_not_found", "process_error", ...), not a display string -- the UI maps it to copy +
/// retry affordance per `02-visual.md`'s failure card state.
class Failure extends CuttingEvent {
  const Failure({required this.reason, required this.retryable});
  final String reason;
  final bool retryable;
}

/// One proposed cut region. [bbox] is in the source image's own real pixel coordinates (already
/// rescaled from the model's fixed inference resolution -- see
/// `segment_image.py`'s `infer_regions_with_crops`, 03-specifications.md Finding 6).
///
/// [cropPng] is a plain rectangular crop, not an alpha-masked cutout -- deliberately named
/// `cropPng`, not `maskPng` as sketched in `sdd-comics-ai-multimodal`'s original Editor
/// Integration Contract, since that name would misdescribe what this iteration actually produces
/// (03-specifications.md's Data Models section explains the rationale).
class DetectedRegion {
  const DetectedRegion({
    required this.kind,
    required this.confidence,
    required this.bbox,
    required this.cropPng,
  });

  /// "background" | "character" | "balloon" | "art" -- matches `Layer.Kind`'s existing open-string
  /// value set (03-specifications.md Finding 2: no schema change needed for any of these).
  final String kind;
  final double confidence;
  final Rect bbox;
  final Uint8List cropPng;

  DetectedRegion copyWith({String? kind, Rect? bbox}) => DetectedRegion(
        kind: kind ?? this.kind,
        confidence: confidence,
        bbox: bbox ?? this.bbox,
        cropPng: cropPng,
      );
}

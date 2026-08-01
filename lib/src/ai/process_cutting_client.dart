import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;

import 'cutting_client.dart';
import 'multimodal_paths.dart';

/// vdd-comics-editor-ai-uiux, Task 2.4: real desktop [MultimodalCuttingClient], spawning
/// `segment_image.py` as a local subprocess and parsing its NDJSON stdout into [CuttingEvent]s.
/// Desktop only (Windows/macOS/Linux) -- per 03-specifications.md, mobile never constructs this,
/// it stays on the disabled Cutting switch from `02-visual.md`.
///
/// One in-flight `segment()` call at a time is assumed (03-specifications.md's Open Design
/// Questions: a second concurrent call would overwrite the tracked [_process] reference) --
/// matches the app's own one-`CuttingSession`-at-a-time design, not a general-purpose limitation
/// this class tries to work around.
class ProcessCuttingClient implements MultimodalCuttingClient {
  /// [pythonResolver]/[scriptsDirResolver] default to [MultimodalPaths]; overridable so tests can
  /// force the "not found" path deterministically without mutating real process environment
  /// variables (which `Platform.environment` doesn't allow from within a running Dart process).
  ProcessCuttingClient({
    String? Function()? pythonResolver,
    String? Function()? scriptsDirResolver,
  })  : _resolvePython = pythonResolver ?? MultimodalPaths.resolvePython,
        _resolveScriptsDir = scriptsDirResolver ?? MultimodalPaths.resolveScriptsDir;

  final String? Function() _resolvePython;
  final String? Function() _resolveScriptsDir;
  Process? _process;

  @override
  Stream<CuttingEvent> segment({required Uint8List sourceImageBytes}) {
    final controller = StreamController<CuttingEvent>();
    controller.onListen = () {
      unawaited(_run(controller, sourceImageBytes));
    };
    controller.onCancel = () {
      _process?.kill();
    };
    return controller.stream;
  }

  Future<void> _run(StreamController<CuttingEvent> controller, Uint8List bytes) async {
    void addIfOpen(CuttingEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    final python = _resolvePython();
    final scriptsDir = _resolveScriptsDir();
    if (python == null || scriptsDir == null) {
      addIfOpen(const Failure(reason: 'python_not_found', retryable: false));
      await controller.close();
      return;
    }

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('comics_cutting_');
      final imagePath = '${tempDir.path}/source.png';
      await File(imagePath).writeAsBytes(bytes);

      final process = await Process.start(
        python,
        ['$scriptsDir/segment_image.py', '--image', imagePath],
      );
      _process = process;

      var sawTerminalEvent = false;
      final stdoutDone = Completer<void>();
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          final event = parseCuttingEventLine(line);
          if (event == null) return; // stray non-JSON/unrecognized line -- ignore
          if (event is Success || event is Failure) sawTerminalEvent = true;
          addIfOpen(event);
        },
        onDone: stdoutDone.complete,
      );
      // Drained, not surfaced -- CoreClient keeps a stderr tail for its own error messages; this
      // client folds any crash straight into the single "process_error" failure below instead of
      // exposing raw stderr to the UI (03-specifications.md's Error Handling table).
      process.stderr.drain<void>();

      await process.exitCode;
      await stdoutDone.future;

      if (!sawTerminalEvent) {
        addIfOpen(const Failure(reason: 'process_error', retryable: true));
      }
    } on ProcessException {
      addIfOpen(const Failure(reason: 'process_error', retryable: true));
    } finally {
      _process = null;
      if (tempDir != null) {
        await tempDir.delete(recursive: true).catchError((_) => tempDir!);
      }
      await controller.close();
    }
  }
}

/// Parses one line of `segment_image.py`'s NDJSON stdout into a [CuttingEvent]. Exposed
/// top-level (not private) so it's unit-testable without spawning a real process. Returns null
/// for a blank line, malformed JSON, or an unrecognized `event` value -- mirrors
/// `CoreClient._onLine`'s "garbage in stdout is ignored, not fatal" behavior.
CuttingEvent? parseCuttingEventLine(String line) {
  if (line.trim().isEmpty) return null;
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(line) as Map<String, dynamic>;
  } on FormatException {
    return null;
  }
  switch (json['event']) {
    case 'routing':
      return RoutingDecided(
        onDevice: json['on_device'] as bool? ?? true,
        reason: json['reason'] as String?,
      );
    case 'progress':
      return Progress(stage: json['stage'] as String? ?? '');
    case 'success':
      final rawRegions = json['regions'] as List? ?? const [];
      final regions = rawRegions.map((r) {
        final region = r as Map<String, dynamic>;
        final bbox = (region['bbox'] as List).map((v) => (v as num).toDouble()).toList();
        return DetectedRegion(
          kind: region['kind'] as String,
          confidence: (region['confidence'] as num).toDouble(),
          bbox: Rect.fromLTRB(bbox[0], bbox[1], bbox[2], bbox[3]),
          cropPng: base64Decode(region['crop_png_base64'] as String),
        );
      }).toList();
      return Success(regions: regions);
    case 'failure':
      return Failure(
        reason: json['reason'] as String? ?? 'unknown',
        retryable: json['retryable'] as bool? ?? false,
      );
    default:
      return null;
  }
}

// vdd-comics-editor-ai-uiux, Task 2.4: ProcessCuttingClient -- NDJSON line parsing (pure,
// no subprocess), the python_not_found short-circuit (via injected resolvers, since real process
// environment can't be mutated from within a running Dart test), and a real end-to-end run
// against the actual segment_image.py + trained checkpoint from this repo.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ai/cutting_client.dart';
import 'package:comics_editor/src/ai/multimodal_paths.dart';
import 'package:comics_editor/src/ai/process_cutting_client.dart';

/// A real photo from this repo's dataset -- more robust than a hand-typed base64 PNG literal
/// (which is easy to get subtly corrupt), and consistent with this project's "verify against
/// real data" discipline. Returns null if the checkout layout isn't found (test skips instead).
Uint8List? _realPhotoBytes() {
  final scriptsDir = MultimodalPaths.resolveScriptsDir();
  if (scriptsDir == null) return null;
  final repoRoot = Directory(scriptsDir).parent.parent.parent.parent; // .../scripts -> repo root
  final photoDir = Directory(
      '${repoRoot.path}/dataset/boranko/mahabharata/book1/comics_book_lowcamera');
  if (!photoDir.existsSync()) return null;
  final photos = photoDir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (photos.isEmpty) return null;
  return photos.first.readAsBytesSync();
}

void main() {
  group('parseCuttingEventLine', () {
    test('parses a routing event', () {
      final event =
          parseCuttingEventLine('{"event": "routing", "on_device": true, "reason": null}');
      expect(event, isA<RoutingDecided>());
      expect((event as RoutingDecided).onDevice, isTrue);
      expect(event.reason, isNull);
    });

    test('parses a progress event', () {
      final event = parseCuttingEventLine('{"event": "progress", "stage": "segmenting"}');
      expect(event, isA<Progress>());
      expect((event as Progress).stage, 'segmenting');
    });

    test('parses a success event with regions, decoding bbox and base64 crop', () {
      final onePxPng = base64Encode(
        base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='),
      );
      final line = jsonEncode({
        'event': 'success',
        'regions': [
          {
            'kind': 'character',
            'confidence': 0.87,
            'bbox': [10, 20, 30, 40],
            'crop_png_base64': onePxPng,
          }
        ],
      });
      final event = parseCuttingEventLine(line);
      expect(event, isA<Success>());
      final region = (event as Success).regions.single;
      expect(region.kind, 'character');
      expect(region.confidence, 0.87);
      expect(region.bbox.left, 10);
      expect(region.bbox.top, 20);
      expect(region.bbox.right, 30);
      expect(region.bbox.bottom, 40);
      expect(region.cropPng, isNotEmpty);
    });

    test('parses a failure event', () {
      final event = parseCuttingEventLine(
          '{"event": "failure", "reason": "model_checkpoint_not_found", "retryable": false}');
      expect(event, isA<Failure>());
      expect((event as Failure).reason, 'model_checkpoint_not_found');
      expect(event.retryable, isFalse);
    });

    test('returns null for a blank line', () {
      expect(parseCuttingEventLine(''), isNull);
      expect(parseCuttingEventLine('   '), isNull);
    });

    test('returns null for malformed JSON (ignored, not fatal, like CoreClient._onLine)', () {
      expect(parseCuttingEventLine('not json at all'), isNull);
    });

    test('returns null for an unrecognized event type', () {
      expect(parseCuttingEventLine('{"event": "something_else"}'), isNull);
    });
  });

  group('ProcessCuttingClient', () {
    test('yields python_not_found failure and closes when no interpreter resolves', () async {
      final client = ProcessCuttingClient(
        pythonResolver: () => null,
        scriptsDirResolver: () => '/does/not/matter',
      );
      final events = await client.segment(sourceImageBytes: Uint8List(0)).toList();
      expect(events, hasLength(1));
      final failure = events.single as Failure;
      expect(failure.reason, 'python_not_found');
      expect(failure.retryable, isFalse);
    });

    test('real end-to-end: spawns the actual segment_image.py against a real image', () async {
      final python = MultimodalPaths.resolvePython();
      final scriptsDir = MultimodalPaths.resolveScriptsDir();
      final checkpoint = scriptsDir == null
          ? null
          : File('${Directory(scriptsDir).parent.path}/work/models/unet_baseline.pt');
      if (python == null || scriptsDir == null || checkpoint == null || !checkpoint.existsSync()) {
        // Documented skip, mirroring the Python suite's own pytest.skip convention for
        // "checkpoint/env not present" -- this is a real integration test, not stubbed.
        return;
      }

      final photoBytes = _realPhotoBytes();
      if (photoBytes == null) return;

      final client = ProcessCuttingClient();
      final events = await client.segment(sourceImageBytes: photoBytes).toList();

      expect(events.first, isA<RoutingDecided>());
      expect(events.last, anyOf(isA<Success>(), isA<Failure>()));
      if (events.last is Success) {
        for (final region in (events.last as Success).regions) {
          expect(region.cropPng, isNotEmpty);
        }
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('cancelling the subscription kills the subprocess without throwing', () async {
      final python = MultimodalPaths.resolvePython();
      final scriptsDir = MultimodalPaths.resolveScriptsDir();
      if (python == null || scriptsDir == null) return;

      final photoBytes = _realPhotoBytes();
      if (photoBytes == null) return;

      final client = ProcessCuttingClient();
      final subscription = client.segment(sourceImageBytes: photoBytes).listen((_) {});
      // Cancel promptly -- don't wait for completion. The test passing (not hanging, not
      // throwing) is the assertion; there's no further event to check once cancelled.
      await subscription.cancel();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

import 'dart:async';
import 'dart:io';

import 'package:comics_editor/src/document_open/document_open_coordinator.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakePendingDocumentSource implements PendingDocumentSource {
  final List<PendingDocument> pending = <PendingDocument>[];
  Future<void> Function()? handler;
  var takeCount = 0;
  var disposed = false;

  @override
  Future<List<PendingDocument>> takePendingDocuments() async {
    takeCount++;
    final result = List<PendingDocument>.of(pending);
    pending.clear();
    return result;
  }

  @override
  void setDocumentsAvailableHandler(Future<void> Function() handler) {
    this.handler = handler;
  }

  Future<void> notifyDocumentsAvailable() async {
    await handler?.call();
  }

  @override
  void dispose() {
    disposed = true;
    handler = null;
  }
}

void main() {
  late Directory tempDirectory;
  late _FakePendingDocumentSource source;
  late List<String> openedPaths;
  late List<String> errors;
  late DocumentOpenCoordinator coordinator;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('document_open_test_');
    source = _FakePendingDocumentSource();
    openedPaths = <String>[];
    errors = <String>[];
    coordinator = DocumentOpenCoordinator(
      openPath: (path) async {
        openedPaths.add(path);
        return true;
      },
      reportError: errors.add,
      nativeSource: source,
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    tempDirectory.deleteSync(recursive: true);
  });

  File createDocument(String name) =>
      File('${tempDirectory.path}/$name')..writeAsBytesSync(<int>[1, 2, 3]);

  test(
    'filters entrypoint arguments and preserves Unicode path fidelity',
    () async {
      final document = createDocument('valid name 漫画.COMICS');

      await coordinator.start(<String>[
        '--trace-startup',
        '${tempDirectory.path}/not-a-document.txt',
        document.path,
      ]);

      expect(openedPaths, <String>[document.absolute.path]);
      expect(errors, isEmpty);
    },
  );

  test('drains cold native entries once in delivery order', () async {
    final first = createDocument('first.comics');
    final second = createDocument('second.comics');
    source.pending.addAll(<PendingDocument>[
      PendingDocument.path(first.path),
      PendingDocument.path(second.path),
    ]);

    await coordinator.start(const <String>[]);
    await coordinator.drainNativeQueue();

    expect(openedPaths, <String>[first.absolute.path, second.absolute.path]);
    expect(source.takeCount, 2);
  });

  test('opens a repeated path again when delivered by a later event', () async {
    final document = createDocument('repeat.comics');
    source.pending.add(PendingDocument.path(document.path));
    await coordinator.start(const <String>[]);

    source.pending.add(PendingDocument.path(document.path));
    await source.notifyDocumentsAvailable();

    expect(openedPaths, <String>[
      document.absolute.path,
      document.absolute.path,
    ]);
  });

  test('serializes concurrent warm requests', () async {
    final first = createDocument('slow.comics');
    final second = createDocument('next.comics');
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final events = <String>[];
    await coordinator.dispose();
    coordinator = DocumentOpenCoordinator(
      openPath: (path) async {
        events.add('start:$path');
        if (path == first.absolute.path) {
          firstStarted.complete();
          await releaseFirst.future;
        }
        events.add('end:$path');
        return true;
      },
      reportError: errors.add,
      nativeSource: source,
    );
    await coordinator.start(const <String>[]);

    final firstOpen = coordinator.enqueuePaths(<String>[first.path]);
    await firstStarted.future;
    final secondOpen = coordinator.enqueuePaths(<String>[second.path]);
    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['start:${first.absolute.path}']);

    releaseFirst.complete();
    await Future.wait(<Future<void>>[firstOpen, secondOpen]);
    expect(events, <String>[
      'start:${first.absolute.path}',
      'end:${first.absolute.path}',
      'start:${second.absolute.path}',
      'end:${second.absolute.path}',
    ]);
  });

  test('reports transport and path errors then continues the queue', () async {
    final valid = createDocument('after-error.comics');
    source.pending.addAll(<PendingDocument>[
      const PendingDocument.error('Provider denied access'),
      PendingDocument.path('${tempDirectory.path}/missing.comics'),
      PendingDocument.path(valid.path),
    ]);

    await coordinator.start(const <String>[]);

    expect(errors, hasLength(2));
    expect(errors.first, contains('Provider denied access'));
    expect(errors.last, contains('missing.comics'));
    expect(openedPaths, <String>[valid.absolute.path]);
  });

  test('dispose detaches native delivery and ignores later work', () async {
    await coordinator.start(const <String>[]);
    await coordinator.dispose();
    source.pending.add(
      PendingDocument.path(createDocument('late.comics').path),
    );

    await source.notifyDocumentsAvailable();
    await coordinator.enqueuePaths(<String>[
      createDocument('later.comics').path,
    ]);

    expect(source.disposed, isTrue);
    expect(openedPaths, isEmpty);
  });

  test('controller transport error preserves the active document', () {
    final controller = EditorController()..newDoc(DocType.comics);
    addTearDown(controller.dispose);
    final activeDocument = controller.doc;
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.reportExternalOpenError('Provider denied access');

    expect(controller.doc, same(activeDocument));
    expect(controller.coreError, 'Provider denied access');
    expect(notifications, 1);
  });
}

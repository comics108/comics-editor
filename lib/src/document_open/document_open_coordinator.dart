import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef DocumentPathOpener = Future<bool> Function(String path);
typedef OpenErrorReporter = void Function(String message);

final class PendingDocument {
  const PendingDocument.path(this.path) : error = null;
  const PendingDocument.error(this.error) : path = null;

  final String? path;
  final String? error;
}

abstract interface class PendingDocumentSource {
  Future<List<PendingDocument>> takePendingDocuments();
  void setDocumentsAvailableHandler(Future<void> Function() handler);
  void dispose();
}

final class MethodChannelPendingDocumentSource
    implements PendingDocumentSource {
  MethodChannelPendingDocumentSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'net.nativemind.comics_editor/document_open';

  final MethodChannel _channel;
  Future<void> Function()? _documentsAvailable;

  @override
  void setDocumentsAvailableHandler(Future<void> Function() handler) {
    _documentsAvailable = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'documentsAvailable') {
        await _documentsAvailable?.call();
      }
    });
  }

  @override
  Future<List<PendingDocument>> takePendingDocuments() async {
    final List<Object?>? raw;
    try {
      raw = await _channel.invokeListMethod<Object?>('takePendingDocuments');
    } on MissingPluginException {
      // Windows/Linux use Dart entrypoint arguments and intentionally have no
      // native implementation for this channel. Widget tests do not either.
      return const <PendingDocument>[];
    }
    if (raw == null) return const <PendingDocument>[];

    final entries = <PendingDocument>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final path = value['path'];
      final error = value['error'];
      if (path is String) {
        entries.add(PendingDocument.path(path));
      } else if (error is String) {
        entries.add(PendingDocument.error(error));
      }
    }
    return entries;
  }

  @override
  void dispose() {
    _documentsAvailable = null;
    _channel.setMethodCallHandler(null);
  }
}

final class DocumentOpenCoordinator {
  DocumentOpenCoordinator({
    required this.openPath,
    required this.reportError,
    required this.nativeSource,
  });

  final DocumentPathOpener openPath;
  final OpenErrorReporter reportError;
  final PendingDocumentSource nativeSource;

  Future<void> _tail = Future<void>.value();
  var _started = false;
  var _disposed = false;

  Future<void> start(List<String> entrypointArguments) async {
    if (_started || _disposed) return;
    _started = true;
    nativeSource.setDocumentsAvailableHandler(drainNativeQueue);
    await enqueuePaths(entrypointArguments);
    await drainNativeQueue();
  }

  Future<void> drainNativeQueue() => _schedule(() async {
    final documents = await nativeSource.takePendingDocuments();
    for (final document in documents) {
      if (_disposed) return;
      final error = document.error;
      if (error != null) {
        reportError(error);
        continue;
      }
      final path = document.path;
      if (path != null) await _openCandidate(path, reportWrongExtension: true);
    }
  });

  Future<void> enqueuePaths(Iterable<String> paths) => _schedule(() async {
    for (final path in paths) {
      if (_disposed) return;
      await _openCandidate(path, reportWrongExtension: false);
    }
  });

  Future<void> _openCandidate(
    String candidate, {
    required bool reportWrongExtension,
  }) async {
    if (!_hasComicsExtension(candidate)) {
      if (reportWrongExtension) {
        reportError('Unsupported external document: $candidate');
      }
      return;
    }

    final file = File(candidate).absolute;
    try {
      if (!await file.exists()) {
        reportError('External Comics document does not exist: ${file.path}');
        return;
      }
      final handle = await file.open(mode: FileMode.read);
      await handle.close();
      if (_disposed) return;
      await openPath(file.path);
    } on FileSystemException catch (error) {
      reportError(
        'Unable to read external Comics document '
        '${file.path}: ${error.message}',
      );
    } on Exception catch (error) {
      reportError(
        'Unable to open external Comics document '
        '${file.path}: $error',
      );
    }
  }

  bool _hasComicsExtension(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    return name.toLowerCase().endsWith('.comics');
  }

  Future<void> _schedule(Future<void> Function() action) {
    if (_disposed) return Future<void>.value();
    _tail = _tail.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } on Exception catch (error) {
        if (!_disposed) {
          reportError('Unable to receive external Comics document: $error');
        }
      }
    });
    return _tail;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    nativeSource.dispose();
    await _tail;
  }
}

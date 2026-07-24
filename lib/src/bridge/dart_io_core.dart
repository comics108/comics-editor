import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import 'comics_core.dart';
import 'core_client.dart' show CoreException;

/// Fallback-транспорт для iOS (решение пользователя, 2026-07-23,
/// flows/sdd-comics-editor-v2.9-android-ios): CoreCLR NativeAOT не публикуется
/// для RID `ios-arm64` в .NET 10 (см. README, раздел iOS), поэтому на iOS
/// открытие/сохранение `.comics`/`.puzzle` реализовано на чистом Dart —
/// тот же протокол (`ping`/`openComics`/`saveComics`/`exportPackage`), тот же
/// формат архива (zip: `data.json` + `layers/` + `sounds/`), без внешнего
/// C#-бинарника. `imageInfo` не поддерживается (v1, мобильный UI его не вызывает —
/// см. Edge Cases в 02-specifications.md).
///
/// Файлы, созданные этим ядром, совместимы с desktop/Android-ядром: тот же zip
/// (package:archive пишет стандартный формат), тот же JSON `data.json`
/// (camelCase, `$type` со сборкой `Comics.Editor` — схема формируется на стороне
/// Dart UI в `models_mapping.dart`, ядро её не интерпретирует).
class DartIoCore implements ComicsCore {
  DartIoCore({String? workDirPath}) : _workDirPath = workDirPath;

  /// Для тестов (path_provider недоступен вне engine-теста): явный путь.
  final String? _workDirPath;
  Directory? _workDir;

  @override
  bool get isAvailable => true; // нет внешней зависимости — доступно всегда

  Future<Directory> _work() async {
    if (_workDir != null) return _workDir!;
    final basePath =
        _workDirPath ?? (await getApplicationSupportDirectory()).path;
    final dir = Directory('$basePath/comics-work');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _workDir = dir;
    return dir;
  }

  @override
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    try {
      switch (method) {
        case 'ping':
          final dir = await _work();
          return {'pong': true, 'version': '2.9', 'tempFolder': dir.path};
        case 'openComics':
          return await _openComics(_requirePath(params));
        case 'saveComics':
          return await _saveComics(
              _requirePath(params), params?['comics'] as Map<String, dynamic>?);
        case 'exportPackage':
          return await _zipWorkTo(_requirePath(params));
        case 'imageInfo':
          throw CoreException('imageInfo is not supported by DartIoCore (iOS)');
        default:
          throw CoreException('Unknown method: $method');
      }
    } on CoreException {
      rethrow;
    } on Exception catch (e) {
      throw CoreException(e.toString());
    }
  }

  String _requirePath(Map<String, dynamic>? params) {
    final path = params?['path'] as String?;
    if (path == null || path.isEmpty) {
      throw CoreException('params.path is required');
    }
    return path;
  }

  Future<Map<String, dynamic>> _openComics(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CoreException('File not found: $path');
    }
    final dir = await _work();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final outPath = '${dir.path}/${entry.name}';
      if (entry.isFile) {
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    final dataFile = File('${dir.path}/data.json');
    final comics = dataFile.existsSync()
        ? jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{'width': 1080, 'height': 2160, 'layers': [], 'sounds': []};

    return {'comics': comics, 'tempFolder': dir.path};
  }

  Future<bool> _saveComics(String path, Map<String, dynamic>? comics) async {
    final dir = await _work();
    if (!dir.existsSync()) {
      throw CoreException('No opened comics: call openComics first');
    }
    if (comics != null) {
      final dataFile = File('${dir.path}/data.json');
      dataFile.writeAsStringSync(jsonEncode(comics));
    }
    return _zipWorkTo(path);
  }

  Future<bool> _zipWorkTo(String path) async {
    final dir = await _work();
    if (!dir.existsSync()) {
      throw CoreException('No opened comics: call openComics first');
    }
    final target = File(path);
    if (target.existsSync()) target.deleteSync();
    target.parent.createSync(recursive: true);

    final encoder = ZipFileEncoder();
    encoder.create(path);
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        final relative = entity.path.substring(dir.path.length + 1);
        encoder.addFileSync(entity, relative);
      }
    }
    encoder.close();
    return true;
  }

  @override
  Future<void> dispose() async {}
}

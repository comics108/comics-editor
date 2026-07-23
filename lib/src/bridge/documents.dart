import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Локальное хранилище документов на мобильных (решение Q4:
/// Save — в песочницу приложения без диалогов, Export — системным диалогом).
/// Каталог: `<app documents>/comics/`.
class DocumentsStore {
  static Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/comics');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Путь для сохранения документа с данным именем файла.
  static Future<String> pathFor(String fileName) async =>
      '${(await directory()).path}/$fileName';

  /// Локальные документы, свежие сверху (мобильные «recents»).
  static Future<List<FileSystemEntity>> list() async {
    final dir = await directory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.comics') || f.path.endsWith('.puzzle'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}

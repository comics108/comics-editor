import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// vdd-comics-editor-uiux-lettering, Task 2.2: splits a flat image into
/// 512px tiles matching the editor's on-disk convention -- reverse-engineered
/// from `native/Comics.Editor/Utils/FileManager.cs` (`UpdateTiles`) +
/// `IWS/Utils/ImageMagick.cs` (`CreateTiles`'s `page.x/512 _ page.y/512`
/// naming): filename `<name>_<scale*1000>_<col>_<row><ext>`,
/// `col = floor(x/512)`, `row = floor(y/512)`, edge tiles clipped (not
/// padded) to the image bounds. Comics layers (not puzzle assets) only ever
/// use scale 1.0 (`FileManager.ComicsScales`), so the scale segment is always
/// the literal "1000". This is a second, independent Dart port of the same
/// algorithm already reimplemented once in
/// `apps/comics-ai-baloons/scripts/tiling.py` -- that's a separate Python
/// project this Flutter app can't import, so the logic is duplicated by
/// necessity, not oversight.
const kTileSize = 512;

/// `EditorLayer.name` defaults to its *first image's raw `file` value*
/// (`comicsFromCore` in models_mapping.dart), which for any layer whose
/// first image is already tiled is a template like
/// `"0001_zastavka_{0}_{1}_{2}.png"` -- literal `{0}`/`{1}`/`{2}` and a
/// trailing extension baked in. Using that directly as a naming stem for a
/// *new* file would embed stray placeholders/extensions mid-filename (and
/// confuse the native side's `string.Format`-based tile substitution, which
/// replaces every `{0}`/`{1}`/`{2}` occurrence, not just trailing ones).
/// This strips everything from the first `{` onward, then any extension,
/// giving a clean stem safe to build new filenames from.
String sanitizeStem(String layerName) {
  var stem = layerName;
  final braceIndex = stem.indexOf('{');
  if (braceIndex >= 0) stem = stem.substring(0, braceIndex);
  final dotIndex = stem.lastIndexOf('.');
  if (dotIndex > 0) stem = stem.substring(0, dotIndex);
  stem = stem.replaceAll(RegExp(r'_+$'), '');
  return stem.isEmpty ? 'layer' : stem;
}

class TiledImage {
  const TiledImage({required this.fileTemplate, required this.width, required this.height});

  /// The `Image.File` value the core expects: `<name>_{0}_{1}_{2}<ext>`
  /// (literal `{0}`/`{1}`/`{2}` placeholders -- see `Image.cs`'s `IsTiles`
  /// check for `File.Contains("{0}")`).
  final String fileTemplate;
  final int width;
  final int height;
}

/// Splits [bytes] into 512px tiles and writes them into [layersDir] (the
/// `layers/` subfolder of a document's `CoreDocument.tempFolder`), named
/// `<name>_1000_<col>_<row><ext>`. Returns the file template + real pixel
/// dimensions for the `Image` JSON record (`file`/`width`/`height`).
Future<TiledImage> writeTiles({
  required Uint8List bytes,
  required String layersDir,
  required String name,
  String ext = '.png',
}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('writeTiles: could not decode image bytes');
  }
  final width = decoded.width;
  final height = decoded.height;
  final cols = (width / kTileSize).ceil();
  final rows = (height / kTileSize).ceil();

  await Directory(layersDir).create(recursive: true);

  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final x = col * kTileSize;
      final y = row * kTileSize;
      final tileWidth = (x + kTileSize <= width) ? kTileSize : width - x;
      final tileHeight = (y + kTileSize <= height) ? kTileSize : height - y;
      final tile = img.copyCrop(decoded, x: x, y: y, width: tileWidth, height: tileHeight);
      final pngBytes = img.encodePng(tile);
      final fileName = '${name}_1000_${col}_$row$ext';
      await File('$layersDir/$fileName').writeAsBytes(pngBytes);
    }
  }

  return TiledImage(
    fileTemplate: '${name}_{0}_{1}_{2}$ext',
    width: width,
    height: height,
  );
}

/// Deletes every on-disk tile matching [fileTemplate] (a value previously
/// returned by [writeTiles] via `TiledImage.fileTemplate`, or read back from
/// `Image.file` in `data.json`) out of [layersDir]. Mirrors
/// `FileManager.DeleteTiles`, called before writing a replacement image so
/// stale tiles from a differently-sized previous image don't linger (e.g.
/// the old image had a 3x3 tile grid, the new one only needs 2x2).
/// No-op if [fileTemplate] is null/empty or isn't a tile template.
Future<void> deleteTiles(String layersDir, String? fileTemplate) async {
  if (fileTemplate == null || !fileTemplate.contains('{0}')) return;
  final dir = Directory(layersDir);
  if (!dir.existsSync()) return;
  final regex = _templateToRegex(fileTemplate);
  for (final entity in dir.listSync().whereType<File>()) {
    final base = entity.uri.pathSegments.last;
    if (regex.hasMatch(base)) {
      await entity.delete();
    }
  }
}

/// Writes [bytes] as a single un-tiled file -- mirrors `FileManager.Update`,
/// the path `Image.Update` takes for `Popup` (unlike `File`, popups are
/// never split into 512px tiles: `Update(..., popup: true)` calls
/// `FileManager.Update`, a plain copy, not `UpdateTiles`; no width/height are
/// tracked for popups in the JSON either). Returns the plain filename
/// written (no `{0}`/`{1}`/`{2}` template).
Future<String> writeSingleFile({
  required Uint8List bytes,
  required String layersDir,
  required String name,
  String ext = '.png',
}) async {
  await Directory(layersDir).create(recursive: true);
  final fileName = '$name$ext';
  await File('$layersDir/$fileName').writeAsBytes(bytes);
  return fileName;
}

/// Deletes a single non-tiled file -- the `Popup` counterpart to
/// [deleteTiles]. No-op if [fileName] is null/empty or the file is missing.
Future<void> deleteSingleFile(String layersDir, String? fileName) async {
  if (fileName == null || fileName.isEmpty) return;
  final file = File('$layersDir/$fileName');
  if (file.existsSync()) await file.delete();
}

/// vdd-comics-editor-uiux-lettering, Task 4.2: reconstructs a full-size
/// image from its on-disk 512px tiles -- the read counterpart to
/// [writeTiles], used by the balloon editor card to preview existing
/// artwork. Mirrors `apps/comics-ai-baloons/scripts/tiling.py`'s
/// `stitch_image`, except a missing tile returns null ("can't preview")
/// rather than raising -- a UI caller mid-write or looking at a
/// legacy/partial file is a normal case, not exceptional here.
Future<Uint8List?> stitchImage({
  required String layersDir,
  required String fileTemplate,
  required int width,
  required int height,
}) async {
  if (!fileTemplate.contains('{0}') || width <= 0 || height <= 0) return null;
  final canvas = img.Image(width: width, height: height);
  final cols = (width / kTileSize).ceil();
  final rows = (height / kTileSize).ceil();
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final name =
          fileTemplate.replaceFirst('{0}', '1000').replaceFirst('{1}', '$col').replaceFirst(
              '{2}', '$row');
      final file = File('$layersDir/$name');
      if (!file.existsSync()) return null;
      final tile = img.decodeImage(await file.readAsBytes());
      if (tile == null) return null;
      img.compositeImage(canvas, tile, dstX: col * kTileSize, dstY: row * kTileSize);
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

final _placeholder = RegExp(r'\{[012]\}');

RegExp _templateToRegex(String fileTemplate) {
  final buffer = StringBuffer('^');
  var lastEnd = 0;
  for (final match in _placeholder.allMatches(fileTemplate)) {
    buffer.write(RegExp.escape(fileTemplate.substring(lastEnd, match.start)));
    buffer.write(r'\d+');
    lastEnd = match.end;
  }
  buffer.write(RegExp.escape(fileTemplate.substring(lastEnd)));
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

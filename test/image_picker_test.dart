// vdd-comics-editor-uiux-lettering, Task 6.1: EditorController.pickImageFile/
// pickImagePopup -- the real file-picker dialog for the generic
// "ARTWORK · PER LANGUAGE" section, replacing the old stub that wrote a fake
// filename never actually saved to disk. `file_picker`'s plan-stated
// verification is manual ("pick a real file, confirm it's written and
// displayed correctly"), but the platform layer is a standard federated
// plugin (FilePickerPlatform.instance is swappable), so this fakes just that
// one seam and exercises the real write path (Task 2.3) end to end against
// the real sample.comics fixture -- everything downstream of "the user
// picked a file" is genuinely exercised, not mocked.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// FilePickerPlatform isn't part of file_picker.dart's public barrel export in
// this package version (no separate file_picker_platform_interface package
// either) -- reaching into src/ is the only way to swap the platform
// implementation for a test double.
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ui/controller.dart';
import 'package:flutter_comics/flutter_comics.dart';

class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.result);
  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async =>
      result;
}

Uint8List _solidPng(int width, int height, int r, int g, int b) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

FilePickerResult _resultWithBytes(Uint8List bytes) => FilePickerResult(
      [PlatformFile(name: 'picked.png', size: bytes.length, bytes: bytes)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final realPlatform = FilePickerPlatform.instance;
  tearDown(() => FilePickerPlatform.instance = realPlatform);

  test('pickImageFile reads the picked bytes and writes them through the real tile-write path',
      () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.selectLayer(0);
    final originalFile = controller.selectedLayer!.images[0].file;

    FilePickerPlatform.instance = _FakeFilePickerPlatform(_resultWithBytes(_solidPng(64, 32, 10, 20, 30)));
    final picked = await controller.pickImageFile('en');

    expect(picked, isTrue);
    final newFile = controller.selectedLayer!.images[0].file;
    expect(newFile, isNot(originalFile));
    expect(newFile, contains('{0}')); // a real tile template, not a fake filename

    final tempFolder = controller.coreDoc!.tempFolder!;
    final tileFile = File('$tempFolder/layers/${newFile.replaceAll("{0}_{1}_{2}", "1000_0_0")}');
    expect(tileFile.existsSync(), isTrue);
    final decoded = img.decodeImage(tileFile.readAsBytesSync())!;
    expect(decoded.getPixel(0, 0).r, 10);
    expect(decoded.getPixel(0, 0).g, 20);
    expect(decoded.getPixel(0, 0).b, 30);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('pickImagePopup reads the picked bytes and writes a single un-tiled file', () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.selectLayer(0);

    FilePickerPlatform.instance = _FakeFilePickerPlatform(_resultWithBytes(_solidPng(16, 16, 1, 2, 3)));
    final picked = await controller.pickImagePopup('en');

    expect(picked, isTrue);
    final popup = controller.selectedLayer!.images[0].popup;
    expect(popup, isNotEmpty);
    expect(popup.contains('{0}'), isFalse); // popups are never tiled

    final tempFolder = controller.coreDoc!.tempFolder!;
    expect(File('$tempFolder/layers/$popup').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('cancelling the picker (null result) is not an error and writes nothing', () async {
    final controller = EditorController();
    expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
    controller.selectLayer(0);
    final originalFile = controller.selectedLayer!.images[0].file;

    FilePickerPlatform.instance = _FakeFilePickerPlatform(null);
    final picked = await controller.pickImageFile('en');

    expect(picked, isFalse);
    expect(controller.selectedLayer!.images[0].file, originalFile);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('picking with nothing selected returns false without throwing', () async {
    final controller = EditorController()..newDoc(DocType.comics);
    FilePickerPlatform.instance = _FakeFilePickerPlatform(_resultWithBytes(_solidPng(8, 8, 1, 1, 1)));
    expect(await controller.pickImageFile('en'), isFalse);
    expect(await controller.pickImagePopup('en'), isFalse);
  });
}

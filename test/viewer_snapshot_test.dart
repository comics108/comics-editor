import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_comics_viewer/flutter_comics_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';

void main() {
  test(
    'Viewer snapshot contains the current unsaved document revision',
    () async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      expect(await controller.openPath('test/fixtures/sample.comics'), isTrue);
      controller.setCanvasSize(1777, null);

      await controller.refreshViewer();
      final source = controller.viewerSource as ComicsViewerPath;
      final archive = ZipDecoder().decodeBytes(
        await File(source.path).readAsBytes(),
      );
      final data = archive.findFile('data.json')!;
      final raw = jsonDecode(utf8.decode(data.content)) as Map<String, dynamic>;

      expect(raw['width'], 1777);
      expect(source.revisionKey, isNotNull);
      expect(controller.coreDoc!.path, 'test/fixtures/sample.comics');
    },
  );
}

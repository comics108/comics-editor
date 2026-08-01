// vdd-comics-editor-ai-uiux, Tasks 5.1-5.2: LibraryBrowser's directory scan, search/filter, empty
// states, and "Insert as layer" wiring.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/library_browser.dart';

Uint8List _samplePng() => Uint8List.fromList(img.encodePng(img.Image(width: 12, height: 12)));

void _seedCluster(Directory libraryRoot, String kindDir, String name, int count) {
  final dir = Directory('${libraryRoot.path}/$kindDir/$name')..createSync(recursive: true);
  for (var i = 0; i < count; i++) {
    File('${dir.path}/crop_$i.png').writeAsBytesSync(_samplePng());
  }
}

Widget _host(EditorController controller, Directory libraryRoot) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => LibraryBrowser(
            controller: controller,
            resolveLibraryDir: () => libraryRoot.path,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty state when the library directory has no clusters yet', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('library_browser_empty');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final controller = EditorController()..newDoc(DocType.comics);

    await tester.pumpWidget(_host(controller, tempDir));
    await tester.pump();

    expect(find.textContaining('Library builds up'), findsOneWidget);
  });

  testWidgets('empty state when the checkout itself cannot be resolved', (tester) async {
    final controller = EditorController()..newDoc(DocType.comics);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LibraryBrowser(controller: controller, resolveLibraryDir: () => null),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('checkout not found'), findsOneWidget);
  });

  testWidgets('lists characters and environments with correct names and counts', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('library_browser_populated');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _seedCluster(tempDir, 'characters', 'amba', 11);
    _seedCluster(tempDir, 'characters', 'bhishma', 6);
    _seedCluster(tempDir, 'environments', 'palace-hall', 9);
    final controller = EditorController()..newDoc(DocType.comics);

    await tester.pumpWidget(_host(controller, tempDir));
    await tester.pump();

    expect(find.text('CHARACTERS'), findsOneWidget);
    expect(find.text('ENVIRONMENTS'), findsOneWidget);
    expect(find.text('amba (11)'), findsOneWidget);
    expect(find.text('bhishma (6)'), findsOneWidget);
    expect(find.text('palace-hall (9)'), findsOneWidget);
  });

  testWidgets('search filters clusters by name, with an empty-result message', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('library_browser_search');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _seedCluster(tempDir, 'characters', 'amba', 3);
    _seedCluster(tempDir, 'characters', 'bhishma', 2);
    final controller = EditorController()..newDoc(DocType.comics);

    await tester.pumpWidget(_host(controller, tempDir));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'amb');
    await tester.pump();
    expect(find.text('amba (3)'), findsOneWidget);
    expect(find.text('bhishma (2)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.textContaining('No characters or environments match "xyz"'), findsOneWidget);
  });

  testWidgets('Insert as layer reads real bytes and calls insertLibraryItemAsLayer', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('library_browser_insert');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    _seedCluster(tempDir, 'characters', 'amba', 1);

    final controller = EditorController();
    await tester.runAsync(() async {
      final opened = await controller.openPath('test/fixtures/sample.comics');
      if (!opened) throw StateError('failed to open sample.comics: ${controller.coreError}');
    });

    await tester.pumpWidget(_host(controller, tempDir));
    await tester.pump();

    final before = controller.doc!.layers.length;
    await tester.runAsync(() async {
      await tester.tap(find.text('Insert as layer'));
      await tester.pump();
    });
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (controller.doc!.layers.length > before) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();

    expect(controller.doc!.layers.length, before + 1);
    expect(controller.doc!.layers.last.kind, 'character');
  });
}

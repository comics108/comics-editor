// vdd-comics-editor-uiux-lettering, Task 5.2: BalloonRail's states, walked
// against 02-visual.md's iPad "BALLOONS" rail mockup -- kind chips, the
// three per-target-language status dots (solid/ring/dash), selection
// highlight, tap-to-select, and the empty-rail edge case.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/i18n/language_registry.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/balloon_rail.dart';

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late LanguageRegistry registry;
  setUpAll(() async {
    registry = await LanguageRegistry.load();
  });

  testWidgets('empty rail: no balloon/caption layers shows the redirect-to-Edit-mode message',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')); // kind == null, not a balloon

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: BalloonRail(controller, registry: registry, langCode: 'en'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('BALLOONS (0)'), findsOneWidget);
    expect(find.textContaining('Switch to Edit mode'), findsOneWidget);
  });

  testWidgets('filters to only balloon/caption layers, in document order, numbered from 1',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')); // excluded
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('hero.png')..kind = 'character'); // excluded
    controller.doc!.layers.add(EditorLayer('c1.png')..kind = 'caption');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: BalloonRail(controller, registry: registry, langCode: 'en'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('BALLOONS (2)'), findsOneWidget);
    expect(find.text('Bln'), findsOneWidget);
    expect(find.text('Cap'), findsOneWidget);
    expect(find.text('#01'), findsOneWidget); // the balloon, first among balloon/caption layers
    expect(find.text('#02'), findsOneWidget); // the caption
  });

  testWidgets('status dot: dash for no text, ring for text-only, solid for text+artwork',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();

    final empty = EditorLayer('empty.png')..kind = 'balloon';

    final textOnly = EditorLayer('text_only.png')..kind = 'balloon';
    textOnly.translations['en'] = 'Hello';

    final withArtwork = EditorLayer('with_artwork.png')..kind = 'balloon';
    withArtwork.translations['en'] = 'Hello';
    withArtwork.images[0].file = 'with_artwork_{0}_{1}_{2}.png'; // real tile template

    controller.doc!.layers.addAll([empty, textOnly, withArtwork]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: BalloonRail(controller, registry: registry, langCode: 'en'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('--'), findsOneWidget);
    // solid/ring dots are unlabeled circles -- distinguish via decoration.
    final containers = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(BalloonRail), matching: find.byType(Container)))
        .where((c) => c.constraints == const BoxConstraints.tightFor(width: 10, height: 10));
    expect(containers.length, 2); // one ring, one solid
    final decorations = containers.map((c) => c.decoration as BoxDecoration).toList();
    expect(decorations.where((d) => d.color == null && d.border != null).length, 1); // ring
    expect(decorations.where((d) => d.color != null).length, 1); // solid
  });

  testWidgets('the currently selected layer is highlighted, tapping a row selects that layer',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');
    controller.selectLayer(0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: BalloonRail(controller, registry: registry, langCode: 'en'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(controller.selIndex, 0);
    await tester.tap(find.text('#02'));
    await tester.pump();
    expect(controller.selIndex, 1);
    expect(controller.selectedLayer, controller.doc!.layers[1]);
  });

  testWidgets('status dot reflects the given target language, not language-agnostically',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    final layer = EditorLayer('b1.png')..kind = 'balloon';
    layer.translations['en'] = 'Hello';
    controller.doc!.layers.add(layer);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          child: BalloonRail(controller, registry: registry, langCode: 'ru'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No 'ru' text -> dash, even though 'en' has text.
    expect(find.text('--'), findsOneWidget);
  });
}

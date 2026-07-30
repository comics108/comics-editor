// vdd-comics-editor-uiux-lettering, Task 3.1: kind chip in the Scene panel's
// layer list (02-visual.md "Scene panel — layer list with kind badges").
// [Bln]/[Cap] for balloon/caption, [Art] (neutral, no glyph) for every other
// or unset kind -- a legacy layer (kind == null) renders as [Art], which is
// the visual's stated backward-compat acceptance criterion, not literally
// "no chip" (the mockup draws [Art] explicitly even in the legacy-file state).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/scene_panel.dart';

/// A generous real viewport (matching widget_test.dart's pattern) -- the
/// default flutter test surface is only ~600px tall, which clamps a nested
/// SizedBox's requested height and silently drops off-screen ListView items
/// instead of throwing, so tests must set this explicitly rather than rely
/// on a big SizedBox alone.
Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScenePanel(WidgetTester tester, EditorController controller) async {
  await tester.pumpWidget(MaterialApp(
    home: EditorScope(controller: controller, child: const Scaffold(body: ScenePanel())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mixed-kind layers each show the correct chip label', (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')..kind = null);
    controller.doc!.layers.add(EditorLayer('hero_balloon_04.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('caption_02.png')..kind = 'caption');

    await _pumpScenePanel(tester, controller);

    expect(find.text('Art'), findsOneWidget);
    expect(find.text('Bln'), findsOneWidget);
    expect(find.text('Cap'), findsOneWidget);
  });

  testWidgets('legacy layers (no kind field at all) all render as the neutral [Art] chip',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('one.png'));
    controller.doc!.layers.add(EditorLayer('two.png'));
    for (final layer in controller.doc!.layers) {
      expect(layer.kind, isNull); // sanity: truly unset, not defaulted elsewhere
    }

    await _pumpScenePanel(tester, controller);

    expect(find.text('Art'), findsNWidgets(2));
    expect(find.text('Bln'), findsNothing);
    expect(find.text('Cap'), findsNothing);
  });

  testWidgets(
      'full background/character/balloon/caption/sound taxonomy each show '
      'their own chip label, unknown kind falls back to [Art]', (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('sky.png')..kind = 'background');
    controller.doc!.layers.add(EditorLayer('hero.png')..kind = 'character');
    controller.doc!.layers.add(EditorLayer('balloon.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('caption.png')..kind = 'caption');
    controller.doc!.layers.add(EditorLayer('sfx.png')..kind = 'sound');
    controller.doc!.layers.add(EditorLayer('mystery.png')..kind = 'something_future');

    await _pumpScenePanel(tester, controller);

    expect(find.text('Bg'), findsOneWidget);
    expect(find.text('Chr'), findsOneWidget);
    expect(find.text('Bln'), findsOneWidget);
    expect(find.text('Cap'), findsOneWidget);
    expect(find.text('Snd'), findsOneWidget);
    expect(find.text('Art'), findsOneWidget); // the unrecognized 'something_future' kind
  });
}

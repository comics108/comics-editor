// tdd-dot-comics-format, Plan Task 5.5: the "Driven by" control on each
// Anim editor (Translate/Rotate/Scale/Alpha, not Sound) toggles
// Anim.basis -- defaults to Scroll position, switching to Time relabels
// Start/End to their millisecond units per `04-visual.md` Screen 5.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/widgets/properties_panel.dart';

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a new anim defaults to Scroll position, Start/End unlabelled with units',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    controller.addAnim(AnimType.rotate);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DRIVEN BY'), findsOneWidget);
    expect(find.text('Scroll position'), findsOneWidget);
    expect(find.text('Time (wall-clock)'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Start (ms)'), findsNothing);
    expect(controller.currentAnim!.basis, AnimBasis.scroll);
  });

  testWidgets('tapping Time (wall-clock) switches basis and relabels Start/End to ms',
      (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    controller.addAnim(AnimType.rotate);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time (wall-clock)'));
    await tester.pumpAndSettle();

    expect(controller.currentAnim!.basis, AnimBasis.time);
    expect(find.text('Start (ms)'), findsOneWidget);
    expect(find.text('End (ms)'), findsOneWidget);

    await tester.tap(find.text('Scroll position'));
    await tester.pumpAndSettle();
    expect(controller.currentAnim!.basis, AnimBasis.scroll);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('the Driven by control is not shown for Sound anims', (tester) async {
    await _setLargeViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addSound();
    controller.addAnim(AnimType.sound);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const Scaffold(body: PropertiesPanel())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DRIVEN BY'), findsNothing);
  });
}

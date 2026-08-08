// vdd-comics-editor-uiux-lettering, Task 5.5: iPhone two-screen Lettering
// flow (02-visual.md "Screen: Lettering mode — iPhone") -- balloon list
// screen and balloon editor screen, same one-tap-from-list depth as the
// other platforms, using selection state (not a pushed route) to switch.
//
// See lettering_desktop_test.dart's file-level comment for why entering
// Lettering mode needs tester.runAsync() to settle reliably.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/editor_mode.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';
import 'package:comics_editor/src/ui/widgets/balloon_rail.dart';

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844); // within the <=600 phone band
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _toggleModeAndSettle(WidgetTester tester, EditorController controller) async {
  await tester.runAsync(() async {
    controller.toggleMode();
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if (!tester.binding.hasScheduledFrame) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets(
      'entering Lettering with balloons lands directly on the editor screen '
      '(auto-selected first balloon), with a back-to-list button',
      (tester) async {
    await _setPhoneViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    await _toggleModeAndSettle(tester, controller);

    expect(controller.mode, EditorMode.lettering);
    expect(controller.selIndex, 0);
    expect(find.text('Balloons'), findsOneWidget); // back button
    expect(find.text('LANGUAGE'), findsOneWidget); // BalloonEditorCard's section label
    expect(find.byType(BalloonRail), findsNothing); // editor screen, not the list
  });

  testWidgets('tapping "Balloons" goes back to the list screen', (tester) async {
    await _setPhoneViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();
    await _toggleModeAndSettle(tester, controller);

    expect(find.text('Balloons'), findsOneWidget);
    await tester.tap(find.text('Balloons'));
    await tester.pumpAndSettle();

    expect(find.byType(BalloonRail), findsOneWidget);
    expect(find.text('BALLOONS (1)'), findsOneWidget);
    expect(controller.selKind, SelKind.none);
  });

  testWidgets('zero balloon layers: lands on the list screen showing the empty state',
      (tester) async {
    await _setPhoneViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer(); // not a balloon

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();
    await _toggleModeAndSettle(tester, controller);

    expect(find.byType(BalloonRail), findsOneWidget);
    expect(find.text('BALLOONS (0)'), findsOneWidget);
    expect(find.textContaining('Switch to Edit mode'), findsOneWidget);
  });

  testWidgets('tapping a balloon in the list navigates to its editor screen', (tester) async {
    await _setPhoneViewport(tester);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.layers.clear();
    controller.doc!.layers.add(EditorLayer('b1.png')..kind = 'balloon');
    controller.doc!.layers.add(EditorLayer('b2.png')..kind = 'balloon');

    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();
    await _toggleModeAndSettle(tester, controller);

    // Go back to the list first (auto-selection already landed on the editor).
    await tester.tap(find.text('Balloons'));
    await tester.pumpAndSettle();
    expect(find.byType(BalloonRail), findsOneWidget);

    await tester.tap(find.text('#02'));
    await tester.pumpAndSettle();

    expect(controller.selIndex, 1);
    expect(find.byType(BalloonRail), findsNothing);
    expect(find.text('LANGUAGE'), findsOneWidget);
  });
}

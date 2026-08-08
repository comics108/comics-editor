import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_comics_viewer/flutter_comics_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/device_profile.dart';
import 'package:comics_editor/src/ui/editor_mode.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';
import 'package:comics_editor/src/ui/widgets/numeric_property_control.dart';
import 'package:comics_editor/src/ui/widgets/properties_panel.dart';
import 'package:comics_editor/src/ui/widgets/scene_panel.dart';
import 'package:comics_editor/src/ui/widgets/dialogs.dart';
import 'package:comics_editor/src/ui/widgets/viewer_workspace.dart';

Widget _app(EditorController controller, Widget child) => MaterialApp(
  home: EditorScope(controller: controller, child: child),
);

void main() {
  testWidgets('phone dock is exactly Scene, Viewer, Properties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() {
      tester.view.reset();
    });
    final controller = EditorController()..newDoc(DocType.comics);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, const EditorScreen()));
    await tester.pump();

    expect(find.text('Scene'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('New'), findsNothing);
    expect(find.text('Open'), findsNothing);

    await tester.tap(find.text('Viewer'));
    await tester.pump();
    expect(find.byType(ComicsViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('viewer-position-right-edge')),
      findsOneWidget,
    );
    final targetViewport = tester.getSize(
      find.byKey(const ValueKey('viewer-target-device-viewport')),
    );
    expect(targetViewport.width / targetViewport.height, closeTo(3 / 4, .001));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop Viewer hides editing panes and keeps right-edge rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 920);
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() {
      tester.view.reset();
    });
    final controller = EditorController()..newDoc(DocType.comics);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, const EditorScreen()));
    controller.setWorkspace(EditorWorkspace.viewer);
    await tester.pump();

    expect(find.byType(ScenePanel), findsNothing);
    expect(find.byType(PropertiesPanel), findsNothing);
    expect(find.byType(ComicsViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('viewer-position-right-edge')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'Properties tabs are Selection, Document, General and Scene has eyes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = EditorController()..newDoc(DocType.comics);
      controller.addLayer();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          controller,
          const Scaffold(
            body: Row(
              children: [
                SizedBox(width: 340, child: ScenePanel()),
                SizedBox(width: 340, child: PropertiesPanel()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selection = tester.getCenter(find.text('Selection'));
      final document = tester.getCenter(find.text('Document'));
      final general = tester.getCenter(find.text('General'));
      expect(selection.dx, lessThan(document.dx));
      expect(document.dx, lessThan(general.dx));
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.text('CANVAS'), findsNothing);

      await tester.tap(find.text('Document'));
      await tester.pump();
      expect(find.text('Width'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);

      controller.doc!.height = 10000;
      await tester.tap(find.text('General'));
      await tester.pump();
      expect(find.text('TARGET VIEWPORT'), findsOneWidget);
      expect(find.text('iPad · 768 × 1024'), findsOneWidget);
      expect(find.text('1440 px · 14%'), findsOneWidget);

      await tester.tap(find.text('iPad · 768 × 1024'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('iPhone · 390 × 844').last);
      await tester.pumpAndSettle();
      expect(controller.targetDeviceProfile, same(DeviceProfile.iPhone));
      expect(find.text('2337 px · 23%'), findsOneWidget);
    },
  );

  testWidgets('Viewer position control exposes the selected-device range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 600,
              child: VerticalPositionSelector(
                value: .5,
                visibleFraction: .2,
                profileLabel: 'iPad',
                enabled: true,
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('viewer-visible-range')), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('viewer-position-right-edge')),
    );
    expect(semantics.label, 'Viewer visible range');
    expect(semantics.value, 'iPad, 40% to 60%');

    final selector = find.byKey(const ValueKey('viewer-position-right-edge'));
    await tester.tapAt(tester.getTopLeft(selector) + const Offset(28, 450));
    await tester.pump();
    expect(changed, isNotNull);
    expect(changed!, greaterThan(.5));
  });

  testWidgets('touch exact number opens selected editor in one tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    num value = 12;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericPropertyControl(
            label: 'Translate X',
            value: value,
            min: -100,
            max: 100,
            step: 1,
            onPreview: (next) => value = next,
            onCommit: (next) => value = next,
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('12'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('exact number commits on blur and Escape cancels the draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    num value = 12;
    final commits = <num>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: NumericPropertyControl(
              label: 'Angle',
              value: value,
              min: -360,
              max: 360,
              step: 1,
              onPreview: (_) {},
              onCommit: (next) => setState(() {
                value = next;
                commits.add(next);
              }),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '42.5');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(commits, isEmpty);
    expect(find.widgetWithText(TextField, '12'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '-7.5');
    await tester.tapAt(const Offset(900, 700));
    await tester.pump();
    expect(commits, [-7.5]);
  });

  // tdd-dot-comics-format, Plan Task 2.3/2.4: this test used to document the
  // dialog's tiles as permanently disabled/cosmetic (2 lock icons, tapping
  // Horizontal-scroll was a no-op). That's precisely what this phase wired
  // for real -- updated to assert the new, real behavior instead of the old
  // "not implemented yet" one.
  testWidgets('new document dialog options are real and wired to the created doc', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = EditorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        controller,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showNewDialog(context),
            child: const Text('Show new'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show new'));
    await tester.pumpAndSettle();

    expect(find.text('Vertical-scroll comic strip'), findsOneWidget);
    expect(find.text('Horizontal-scroll comic strip'), findsOneWidget);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    // Horizontal-scroll and Landscape were the only 2 locked tiles; both
    // are real, tappable options now.
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.tap(find.text('Horizontal-scroll comic strip'));
    await tester.tap(find.text('Landscape'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(controller.doc?.type, DocType.comics);
    expect(controller.doc?.scrollType, ScrollType.horizontal);
    expect(controller.doc?.preferredOrientation, PreferredOrientation.landscape);
  });
}

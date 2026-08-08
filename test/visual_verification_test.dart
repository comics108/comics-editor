import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/editor_mode.dart';
import 'package:flutter_comics/flutter_comics.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';

Widget _app(EditorController controller) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: EditorScope(controller: controller, child: const EditorScreen()),
);

void main() {
  testWidgets('desktop Editor reference', (tester) async {
    tester.view.physicalSize = const Size(1440, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/editor_desktop_1440x920.png'),
    );
  });

  testWidgets('Viewer reference with right-edge position rail', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1240, 864);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    controller.setWorkspace(EditorWorkspace.viewer);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/viewer_1240x864.png'),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phone Properties sheet reference', (tester) async {
    tester.view.physicalSize = const Size(400, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.addLayer();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/properties_phone_400x844.png'),
    );
  });

  testWidgets('General target viewport reference', (tester) async {
    tester.view.physicalSize = const Size(1440, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = EditorController()..newDoc(DocType.comics);
    controller.doc!.height = 33000;
    controller.setPropertiesTab(PropertiesTab.general);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/general_target_viewport_1440x920.png'),
    );
  });
}

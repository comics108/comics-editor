import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/main.dart';
import 'package:comics_editor/src/app_version.dart';
import 'package:comics_editor/src/ui/controller.dart';
import 'package:comics_editor/src/ui/models.dart';
import 'package:comics_editor/src/ui/screens/editor_screen.dart';

void main() {
  testWidgets('Editor UI smoke test (maket)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ComicsEditorApp());
    await tester.pumpAndSettle();

    expect(find.byType(ComicsEditorApp), findsOneWidget);
  });

  testWidgets('top bar shows the current app version, not a hardcoded one',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The top bar only renders once a document is open (EditorScreen shows
    // the Welcome screen otherwise), so open one before pumping.
    final controller = EditorController()..newDoc(DocType.comics);
    await tester.pumpWidget(MaterialApp(
      home: EditorScope(controller: controller, child: const EditorScreen()),
    ));
    await tester.pumpAndSettle();

    // main() isn't run in a widget test, so AppVersion.load() hasn't executed --
    // this asserts the header reads whatever AppVersion.current is (fallback
    // here), not a literal '3.0'/'2.9' baked into the widget.
    expect(find.text(AppVersion.current), findsOneWidget);
    expect(find.text('3.0'), findsNothing);
  });
}

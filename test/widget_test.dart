import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comics_editor/main.dart';

void main() {
  testWidgets('Editor UI smoke test (maket)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ComicsEditorApp());
    await tester.pumpAndSettle();

    expect(find.byType(ComicsEditorApp), findsOneWidget);
  });
}

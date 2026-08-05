import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app_version.dart';
import 'src/document_open/document_open_coordinator.dart';
import 'src/ui/controller.dart';
import 'src/ui/screens/editor_screen.dart';
import 'src/ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppVersion.load();
  runApp(ComicsEditorApp(initialArguments: args));
}

/// Comics Editor v2.9.
///
/// Этап 1 (Windows): существующий WPF-редактор как есть, встроенный через
/// PlatformView ([WpfEditorView]); до завершения C++/CLI-слоя показывается
/// заглушка с инструкцией.
/// Этап 2 (macOS/Linux): Flutter-интерфейс из design/comics-editor-maket-dart-v3
/// (lib/src/ui) + headless-ядро Comics.Editor.Headless для работы с файлами.
class ComicsEditorApp extends StatefulWidget {
  const ComicsEditorApp({super.key, this.initialArguments = const <String>[]});

  final List<String> initialArguments;

  @override
  State<ComicsEditorApp> createState() => _ComicsEditorAppState();
}

class _ComicsEditorAppState extends State<ComicsEditorApp> {
  final EditorController controller = EditorController();
  late final DocumentOpenCoordinator documentOpenCoordinator;

  @override
  void initState() {
    super.initState();
    documentOpenCoordinator = DocumentOpenCoordinator(
      openPath: controller.openPath,
      reportError: controller.reportExternalOpenError,
      nativeSource: MethodChannelPendingDocumentSource(),
    );
    unawaited(documentOpenCoordinator.start(widget.initialArguments));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comics Editor',
      debugShowCheckedModeBanner: false,
      theme: buildHolySpotsTheme(),
      home: EditorScope(controller: controller, child: const EditorScreen()),
    );
  }

  @override
  void dispose() {
    unawaited(documentOpenCoordinator.dispose());
    controller.dispose();
    super.dispose();
  }
}

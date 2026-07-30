import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app_version.dart';
import 'src/bridge/wpf_editor_view.dart';
import 'src/ui/controller.dart';
import 'src/ui/screens/editor_screen.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppVersion.load();
  runApp(const ComicsEditorApp());
}

/// Comics Editor v2.9.
///
/// Этап 1 (Windows): существующий WPF-редактор как есть, встроенный через
/// PlatformView ([WpfEditorView]); до завершения C++/CLI-слоя показывается
/// заглушка с инструкцией.
/// Этап 2 (macOS/Linux): Flutter-интерфейс из design/comics-editor-maket-dart-v3
/// (lib/src/ui) + headless-ядро Comics.Editor.Headless для работы с файлами.
class ComicsEditorApp extends StatefulWidget {
  const ComicsEditorApp({super.key});

  @override
  State<ComicsEditorApp> createState() => _ComicsEditorAppState();
}

class _ComicsEditorAppState extends State<ComicsEditorApp> {
  final EditorController controller = EditorController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comics Editor',
      debugShowCheckedModeBanner: false,
      theme: buildHolySpotsTheme(),
      home: Platform.isWindows
          ? const WpfEditorView()
          : EditorScope(
              controller: controller,
              child: const EditorScreen(),
            ),
    );
  }
}

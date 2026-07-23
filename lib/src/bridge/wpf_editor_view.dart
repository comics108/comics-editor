import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Встроенный WPF-редактор (этап 1, только Windows).
///
/// Полный редактор v2.8 отображается как PlatformView `comics_editor_view`,
/// который регистрирует нативный плагин `windows/editor_plugin` через
/// C++/CLI-слой и `native/Comics.Editor.Flutter`. Пока слой не собран на
/// Windows-машине (см. README, раздел «Windows»), виджет показывает заглушку.
class WpfEditorView extends StatefulWidget {
  const WpfEditorView({super.key});

  static const MethodChannel channel = MethodChannel('comics_editor');

  @override
  State<WpfEditorView> createState() => _WpfEditorViewState();
}

class _WpfEditorViewState extends State<WpfEditorView> {
  bool _nativeAvailable = false;

  @override
  void initState() {
    super.initState();
    _probeNative();
  }

  Future<void> _probeNative() async {
    try {
      await WpfEditorView.channel.invokeMethod<void>('create');
      if (mounted) setState(() => _nativeAvailable = true);
    } on MissingPluginException {
      // C++/CLI-слой ещё не собран — остаёмся на заглушке.
    } on PlatformException {
      // Плагин есть, но view недоступна — тоже заглушка.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nativeAvailable) {
      // Хост нативной WPF-поверхности. Конкретный view-тип регистрируется
      // плагином; до его появления ветка недостижима.
      return const Scaffold(body: Center(child: Text('comics_editor_view')));
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('WPF-редактор ещё не подключён',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text(
                'Полный редактор v2.8 встраивается на Windows через '
                'PlatformView. Для этого на Windows-машине нужно собрать '
                'C++/CLI-слой и native/Comics.Editor.Flutter — шаги описаны '
                'в README проекта (раздел «Windows»).',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

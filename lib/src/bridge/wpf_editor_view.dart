import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Встроенный WPF-редактор (этап 1, только Windows).
///
/// Полный редактор v2.8 показывается как отдельное top-level WPF-окно
/// (`EditorHost.ShowMainWindow`), поднятое нативным плагином
/// `windows/editor_plugin` через hostfxr-интероп в `native/Comics.Editor.Flutter`
/// (см. sdd-comics-editor-v2.9-fixes2). Встраивание как PlatformView в дерево
/// Flutter-виджетов — следующий шаг, ещё не сделан; до тех пор виджет здесь
/// показывает заглушку с текстом даже при успешном `create`.
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
      // Плагин не зарегистрирован в этой сборке (например, сборка старше
      // sdd-comics-editor-v2.9-fixes2 или для другой платформы) — заглушка.
    } on PlatformException {
      // Плагин есть, но интероп не смог инициализироваться (например, на
      // машине не установлен .NET 10 runtime, см. hostfxr_bootstrap.cpp) —
      // тоже заглушка.
    }
  }

  @override
  void dispose() {
    // sdd-comics-editor-v2.9-fixes2 (Track A): fire-and-forget — dispose()
    // is synchronous, and by this point there's no `mounted` state left to
    // gate a result on. Only meaningful if `create` actually succeeded
    // (_nativeAvailable) — CallHandleMethodCall/hostfxr on the native side
    // no-ops harmlessly either way if the host was never initialized.
    if (_nativeAvailable) {
      WpfEditorView.channel.invokeMethod<void>('dispose');
    }
    super.dispose();
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
              Text('WPF-редактор недоступен',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text(
                'Не удалось открыть редактор v2.8. Обычно это значит, что на '
                'машине не установлен .NET 10 runtime, либо сборка не '
                'содержит нативный плагин windows/editor_plugin — шаги '
                'описаны в README проекта (раздел «Windows»).',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

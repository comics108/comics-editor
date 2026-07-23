using System.Windows;
using System.Windows.Threading;

using Comics.Editor.Windows;

namespace Comics.Editor.Flutter;

/// <summary>
/// Хост полного WPF-редактора внутри процесса Flutter-приложения (этап 1).
///
/// Поднимает STA-поток с WPF Dispatcher и показывает существующий
/// <see cref="MainWindow"/> как есть — весь workflow v2.8 (New/Open/Save,
/// языки, слои, звуки) работает без изменений C#-кода.
///
/// Вызывается из C++-плагина (windows/editor_plugin) через hosting-слой;
/// следующий шаг (встраивание ComicsControl как PlatformView в окно Flutter)
/// выполняется на Windows-машине — см. README, раздел «Windows».
/// </summary>
public static class EditorHost
{
    private static Thread? _uiThread;
    private static Dispatcher? _dispatcher;
    private static MainWindow? _window;

    /// <summary>Показывает окно редактора (создаёт WPF-поток при первом вызове).</summary>
    public static void ShowMainWindow()
    {
        if (_dispatcher != null)
        {
            _dispatcher.Invoke(() =>
            {
                if (_window == null)
                {
                    _window = new MainWindow();
                    _window.Closed += (_, _) => _window = null;
                }
                _window.Show();
                _window.Activate();
            });
            return;
        }

        var ready = new ManualResetEventSlim();
        _uiThread = new Thread(() =>
        {
            _dispatcher = Dispatcher.CurrentDispatcher;
            _window = new MainWindow();
            _window.Closed += (_, _) => _window = null;
            _window.Show();
            ready.Set();
            Dispatcher.Run();
        })
        {
            IsBackground = true,
            Name = "ComicsEditorWpf",
        };
        _uiThread.SetApartmentState(ApartmentState.STA);
        _uiThread.Start();
        ready.Wait();
    }

    /// <summary>Закрывает окно и останавливает WPF-поток.</summary>
    public static void Shutdown()
    {
        var dispatcher = _dispatcher;
        if (dispatcher == null)
            return;

        dispatcher.Invoke(() => _window?.Close());
        dispatcher.InvokeShutdown();
        _dispatcher = null;
        _uiThread = null;
    }
}

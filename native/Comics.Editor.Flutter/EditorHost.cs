using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;

using Comics.Editor.Controls;
using Comics.Editor.Models;
using Comics.Editor.ViewModel;

namespace Comics.Editor.Flutter;

/// <summary>
/// Owns one viewer-only WPF child HWND inside the Flutter window.
/// </summary>
public static class EditorHost
{
    private static Thread? _uiThread;
    private static Dispatcher? _dispatcher;
    private static HwndSource? _source;
    private static ComicsControl? _control;
    private static ComicsViewModel? _model;
    private static DispatcherTimer? _playTimer;

    private const int WsChild = 0x40000000;
    private const int WsVisible = 0x10000000;
    private const uint SwpNoActivate = 0x0010;
    private const int SwHide = 0;
    private const int SwShowNoActivate = 4;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter,
        int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hwnd, int command);

    public static void Create(long parentHwnd, int x, int y, int width, int height)
    {
        if (_dispatcher != null)
        {
            SetBounds(x, y, width, height);
            SetVisible(true);
            return;
        }

        var ready = new ManualResetEventSlim();
        Exception? startupError = null;
        _uiThread = new Thread(() =>
        {
            try
            {
                _dispatcher = Dispatcher.CurrentDispatcher;
                if (Application.Current == null)
                {
                    var application = new App();
                    application.InitializeComponent();
                }
                var parameters = new HwndSourceParameters("ComicsViewerWpf")
                {
                    ParentWindow = new IntPtr(parentHwnd),
                    WindowStyle = WsChild | WsVisible,
                    PositionX = x,
                    PositionY = y,
                    Width = Math.Max(1, width),
                    Height = Math.Max(1, height),
                    UsesPerPixelOpacity = false,
                };
                _source = new HwndSource(parameters);
                _control = new ComicsControl();
                _source.RootVisual = _control;
            }
            catch (Exception error)
            {
                startupError = error;
                _dispatcher = null;
            }
            finally
            {
                ready.Set();
            }
            if (startupError == null) Dispatcher.Run();
        })
        {
            IsBackground = true,
            Name = "ComicsViewerWpf",
        };
        _uiThread.SetApartmentState(ApartmentState.STA);
        _uiThread.Start();
        ready.Wait();
        if (startupError != null)
        {
            _uiThread = null;
            throw new InvalidOperationException("Could not create the WPF Viewer host", startupError);
        }
    }

    public static void Load(string path) => Invoke(() =>
    {
        _model?.Dispose();
        _model = new ComicsViewModel(path);
        if (_control != null) _control.DataContext = _model;
    });

    public static void SetBounds(int x, int y, int width, int height) => Invoke(() =>
    {
        if (_source != null)
            SetWindowPos(_source.Handle, IntPtr.Zero, x, y, Math.Max(1, width),
                Math.Max(1, height), SwpNoActivate);
    });

    public static void SetVisible(bool visible) => Invoke(() =>
    {
        if (_source != null) ShowWindow(_source.Handle, visible ? SwShowNoActivate : SwHide);
    });

    public static void SetPosition(double position) =>
        Invoke(() => _control?.SetNormalizedPosition(position));

    public static double GetPosition() =>
        _dispatcher?.Invoke(() => _control?.NormalizedPosition ?? 0) ?? 0;

    public static void SetLanguage(int index) => Invoke(() =>
    {
        if (_model == null) return;
        _model.Culture = index switch { 1 => Cultures.Ru, 2 => Cultures.Hi, _ => Cultures.En };
    });

    public static void SetSoundEnabled(bool enabled) =>
        Invoke(() => { if (_model != null) _model.DisableSound = !enabled; });

    public static void SetPreview(bool show) => Invoke(() =>
    {
        if (_model == null) return;
        foreach (var layer in _model.Layers)
            layer.IsVisible = show || !layer.Layer.Preview;
    });

    public static void Play() => Invoke(() =>
    {
        _playTimer ??= new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _playTimer.Tick -= PlayTick;
        _playTimer.Tick += PlayTick;
        _playTimer.Start();
    });

    public static void Pause() => Invoke(() => _playTimer?.Stop());

    private static void PlayTick(object? sender, EventArgs e)
    {
        if (_control == null) return;
        var next = _control.NormalizedPosition + 0.0015;
        _control.SetNormalizedPosition(next >= 1 ? 0 : next);
    }

    private static void Invoke(Action action)
    {
        var dispatcher = _dispatcher ?? throw new InvalidOperationException("Viewer host is not created");
        dispatcher.Invoke(action);
    }

    public static void Shutdown()
    {
        var dispatcher = _dispatcher;
        if (dispatcher == null)
            return;

        dispatcher.Invoke(() =>
        {
            _playTimer?.Stop();
            _playTimer = null;
            if (_control != null) _control.DataContext = null;
            _model?.Dispose();
            _model = null;
            _control = null;
            _source?.Dispose();
            _source = null;
        });
        dispatcher.InvokeShutdown();
        _dispatcher = null;
        _uiThread = null;
    }
}

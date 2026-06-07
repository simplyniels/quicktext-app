using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Forms;
using QuickTextWindows.Services;

namespace QuickTextWindows;

public sealed class App : System.Windows.Application
{
    private NotifyIcon? tray;
    private MainWindow? window;
    private GlobalHotkeyService? hotkeys;

    [STAThread]
    public static void Main()
    {
        try
        {
            var app = new App { ShutdownMode = ShutdownMode.OnExplicitShutdown };
            app.DispatcherUnhandledException += (_, eventArgs) =>
            {
                ShowStartupError(eventArgs.Exception);
                eventArgs.Handled = true;
            };
            app.Run();
        }
        catch (Exception exception)
        {
            ShowStartupError(exception);
        }
    }

    private static void ShowStartupError(Exception exception)
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Quick Text");
        Directory.CreateDirectory(directory);
        var logPath = Path.Combine(directory, "startup-error.log");
        File.WriteAllText(logPath, exception.ToString());
        System.Windows.MessageBox.Show(
            $"Quick Text konnte nicht gestartet werden.\n\n{exception.Message}\n\nDetails: {logPath}",
            "Quick Text Startfehler",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        window = new MainWindow();
        window.HideRequested += (_, _) => window.Hide();
        tray = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "Quick Text ist bereit",
            Visible = true,
            ContextMenuStrip = MakeMenu()
        };
        tray.DoubleClick += (_, _) => ShowWindow();

        hotkeys = new GlobalHotkeyService();
        hotkeys.Triggered += (type, down) => Dispatcher.Invoke(() => window.HandleHotkey(type, down));
        hotkeys.Cancelled += () => Dispatcher.Invoke(window.CancelWorkflow);

        if (!e.Args.Contains("--background") || !window.IsConfigured) ShowWindow();
    }

    private ContextMenuStrip MakeMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("Quick Text öffnen", null, (_, _) => ShowWindow());
        menu.Items.Add(new ToolStripSeparator());
        foreach (var type in WorkflowInfo.Main)
        {
            var captured = type;
            menu.Items.Add(WorkflowInfo.Name(type), null, (_, _) =>
            {
                ShowWindow();
                window!.StartWorkflow(captured);
            });
        }
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Beenden", null, (_, _) => Shutdown());
        return menu;
    }

    private void ShowWindow()
    {
        window!.SetPasteTarget(PasteService.GetForegroundWindow());
        window!.Show();
        window.WindowState = WindowState.Normal;
        window.Activate();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        hotkeys?.Dispose();
        tray?.Dispose();
        base.OnExit(e);
    }
}

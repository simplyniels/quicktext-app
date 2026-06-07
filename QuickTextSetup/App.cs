using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using Microsoft.Win32;

namespace QuickTextSetup;

public sealed class App : Application
{
    [STAThread]
    public static void Main()
    {
        new App().Run(new SetupWindow());
    }
}

public sealed class SetupWindow : Window
{
    private readonly TextBlock status = Text("Bereit zur Installation.", 12.5, FontWeights.SemiBold, Palette.Muted);
    private bool launchAfterInstall = true;
    private bool startAtLogin;
    private Border launchToggle = null!;
    private Border startupToggle = null!;

    public SetupWindow()
    {
        Title = "Quick Text Setup";
        Width = 526;
        Height = 600;
        MinWidth = 526;
        MinHeight = 600;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ResizeMode = ResizeMode.NoResize;
        Background = Palette.WindowBackground;

        var panel = new Border
        {
            CornerRadius = new CornerRadius(26),
            Background = Palette.Panel,
            BorderBrush = Palette.Border,
            BorderThickness = new Thickness(1),
            Padding = new Thickness(30, 26, 30, 24),
            Effect = new DropShadowEffect
            {
                Color = Color.FromRgb(30, 70, 90),
                BlurRadius = 26,
                ShadowDepth = 8,
                Opacity = 0.18
            }
        };

        var root = new StackPanel();
        root.Children.Add(Text("Quick Text", 18, FontWeights.SemiBold, Palette.Muted));

        var ready = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 22, 0, 24)
        };
        ready.Children.Add(new Border
        {
            Width = 11,
            Height = 11,
            CornerRadius = new CornerRadius(7),
            Background = Palette.Success,
            Margin = new Thickness(0, 8, 10, 0)
        });
        ready.Children.Add(Text("Setup", 22, FontWeights.Bold, Palette.Text));
        root.Children.Add(ready);

        var intro = Card();
        var introStack = new StackPanel();
        introStack.Children.Add(Text("Quick Text für Windows 11", 18, FontWeights.Bold, Palette.Text));
        introStack.Children.Add(Text(
            "Installiert Sprache-zu-Text, globale Hotkeys und automatisches Einfügen für den aktuellen Benutzer.",
            13.5,
            FontWeights.Medium,
            Palette.Muted,
            new Thickness(0, 6, 0, 0)));
        intro.Child = introStack;
        root.Children.Add(intro);

        root.Children.Add(SectionTitle("Installation"));
        launchToggle = TogglePill(launchAfterInstall, () =>
        {
            launchAfterInstall = !launchAfterInstall;
            RefreshToggle(launchToggle, launchAfterInstall);
        });
        root.Children.Add(SettingRow("Quick Text danach starten", launchToggle));

        startupToggle = TogglePill(startAtLogin, () =>
        {
            startAtLogin = !startAtLogin;
            RefreshToggle(startupToggle, startAtLogin);
        });
        root.Children.Add(SettingRow("Automatisch mit Windows starten", startupToggle));

        var buttons = new Grid { Margin = new Thickness(0, 26, 0, 0) };
        buttons.ColumnDefinitions.Add(new ColumnDefinition());
        buttons.ColumnDefinitions.Add(new ColumnDefinition());
        var cancel = ButtonShell("Abbrechen", Palette.SegmentBackground, Palette.Text);
        cancel.Margin = new Thickness(0, 0, 6, 0);
        cancel.Click += (_, _) => Close();
        var install = ButtonShell("Installieren", Palette.Accent, Brushes.White);
        install.Margin = new Thickness(6, 0, 0, 0);
        install.IsDefault = true;
        install.Click += (_, _) => Install();
        Grid.SetColumn(install, 1);
        buttons.Children.Add(cancel);
        buttons.Children.Add(install);
        root.Children.Add(buttons);

        status.HorizontalAlignment = HorizontalAlignment.Center;
        status.Margin = new Thickness(0, 18, 0, 0);
        root.Children.Add(status);

        panel.Child = root;
        Content = new Grid { Margin = new Thickness(18), Children = { panel } };
    }

    private void Install()
    {
        try
        {
            status.Text = "Quick Text wird installiert ...";
            var setupDir = AppContext.BaseDirectory;
            var sourceDir = Path.Combine(setupDir, "app");
            var sourceExe = Path.Combine(sourceDir, "Quick Text.exe");
            if (!File.Exists(sourceExe))
            {
                throw new InvalidOperationException("App-Payload fehlt. Bitte den vollständigen entpackten Setup-Ordner verwenden.");
            }

            var installDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "Quick Text");
            if (Directory.Exists(installDir)) Directory.Delete(installDir, true);
            CopyDirectory(sourceDir, installDir);

            var installedExe = Path.Combine(installDir, "Quick Text.exe");
            CreateShortcut(installedExe);
            ConfigureStartup(installedExe, startAtLogin);

            status.Text = "Installation abgeschlossen.";
            if (launchAfterInstall)
            {
                Process.Start(new ProcessStartInfo(installedExe) { UseShellExecute = true });
            }

            MessageBox.Show("Quick Text wurde installiert.", "Quick Text Setup", MessageBoxButton.OK, MessageBoxImage.Information);
            Close();
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
            MessageBox.Show(ex.Message, "Quick Text Setup", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private static Border Card() => new()
    {
        CornerRadius = new CornerRadius(14),
        Background = Palette.Card,
        BorderBrush = Palette.Border,
        BorderThickness = new Thickness(1),
        Padding = new Thickness(16),
        Margin = new Thickness(0, 0, 0, 6)
    };

    private static TextBlock SectionTitle(string value) =>
        Text(value.ToUpperInvariant(), 13, FontWeights.Bold, Palette.Section, new Thickness(0, 22, 0, 12));

    private static Grid SettingRow(string label, UIElement control)
    {
        var row = new Grid { Margin = new Thickness(0, 4, 0, 12) };
        row.ColumnDefinitions.Add(new ColumnDefinition());
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.Children.Add(Text(label, 15, FontWeights.Medium, Palette.Text));
        Grid.SetColumn(control, 1);
        row.Children.Add(control);
        return row;
    }

    private static Border TogglePill(bool enabled, Action action)
    {
        var toggle = new Border
        {
            Width = 58,
            Height = 32,
            CornerRadius = new CornerRadius(18),
            Cursor = Cursors.Hand
        };
        RefreshToggle(toggle, enabled);
        toggle.MouseLeftButtonUp += (_, _) => action();
        return toggle;
    }

    private static void RefreshToggle(Border toggle, bool enabled)
    {
        toggle.Background = enabled ? Palette.Accent : Palette.SegmentBackground;
        toggle.Child = new Border
        {
            Width = 25,
            Height = 25,
            CornerRadius = new CornerRadius(14),
            Background = Brushes.White,
            HorizontalAlignment = enabled ? HorizontalAlignment.Right : HorizontalAlignment.Left,
            Margin = new Thickness(4)
        };
    }

    private static Button ButtonShell(string label, Brush background, Brush foreground) => new()
    {
        Content = label,
        Background = background,
        Foreground = foreground,
        BorderBrush = Brushes.Transparent,
        Padding = new Thickness(14, 10, 14, 10),
        FontSize = 14,
        FontWeight = FontWeights.SemiBold,
        Cursor = Cursors.Hand
    };

    private static TextBlock Text(string value, double size, FontWeight weight, Brush color, Thickness? margin = null) => new()
    {
        Text = value,
        FontSize = size,
        FontWeight = weight,
        Foreground = color,
        TextWrapping = TextWrapping.Wrap,
        Margin = margin ?? new Thickness(0)
    };

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.GetFiles(source))
        {
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), true);
        }
        foreach (var dir in Directory.GetDirectories(source))
        {
            CopyDirectory(dir, Path.Combine(destination, Path.GetFileName(dir)));
        }
    }

    private static void CreateShortcut(string target)
    {
        var startMenu = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
            "Programs",
            "Quick Text.lnk");
        Directory.CreateDirectory(Path.GetDirectoryName(startMenu)!);

        Type? shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null) return;
        dynamic shell = Activator.CreateInstance(shellType)!;
        dynamic shortcut = shell.CreateShortcut(startMenu);
        shortcut.TargetPath = target;
        shortcut.WorkingDirectory = Path.GetDirectoryName(target);
        shortcut.Description = "Quick Text";
        shortcut.Save();
    }

    private static void ConfigureStartup(string target, bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        if (enabled) key.SetValue("Quick Text", $"\"{target}\" --background");
        else key.DeleteValue("Quick Text", false);
    }

    private static class Palette
    {
        public static readonly Brush WindowBackground = new LinearGradientBrush(
            Color.FromRgb(31, 151, 204),
            Color.FromRgb(133, 224, 238),
            90);
        public static readonly Brush Panel = new SolidColorBrush(Color.FromRgb(199, 242, 248));
        public static readonly Brush Card = new SolidColorBrush(Color.FromArgb(88, 160, 217, 228));
        public static readonly Brush Border = new SolidColorBrush(Color.FromArgb(72, 58, 116, 137));
        public static readonly Brush SegmentBackground = new SolidColorBrush(Color.FromArgb(94, 100, 177, 203));
        public static readonly Brush Accent = new SolidColorBrush(Color.FromRgb(0, 115, 255));
        public static readonly Brush Success = new SolidColorBrush(Color.FromRgb(43, 193, 80));
        public static readonly Brush Text = new SolidColorBrush(Color.FromRgb(37, 58, 67));
        public static readonly Brush Muted = new SolidColorBrush(Color.FromRgb(74, 112, 128));
        public static readonly Brush Section = new SolidColorBrush(Color.FromRgb(61, 104, 123));
    }
}

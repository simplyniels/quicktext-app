using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
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
    private readonly TextBlock status = new() { Text = "Bereit zur Installation.", Margin = new Thickness(0, 12, 0, 0) };
    private readonly CheckBox launchAfterInstall = new() { Content = "Quick Text nach der Installation starten", IsChecked = true };
    private readonly CheckBox startAtLogin = new() { Content = "Quick Text automatisch mit Windows starten", IsChecked = false };

    public SetupWindow()
    {
        Title = "Quick Text Setup";
        Width = 440;
        Height = 330;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ResizeMode = ResizeMode.NoResize;

        var root = new StackPanel { Margin = new Thickness(22) };
        root.Children.Add(new TextBlock { Text = "Quick Text", FontSize = 28, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "Installiert die Windows-11-App fuer Sprache zu Text, Hotkeys und automatisches Einfuegen.",
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 8, 0, 16)
        });
        root.Children.Add(launchAfterInstall);
        root.Children.Add(startAtLogin);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var install = new Button { Content = "Installieren", MinWidth = 110, Padding = new Thickness(10, 6, 10, 6), IsDefault = true };
        var cancel = new Button { Content = "Abbrechen", MinWidth = 90, Padding = new Thickness(10, 6, 10, 6), Margin = new Thickness(8, 0, 0, 0), IsCancel = true };
        install.Click += (_, _) => Install();
        cancel.Click += (_, _) => Close();
        buttons.Children.Add(install);
        buttons.Children.Add(cancel);
        root.Children.Add(buttons);
        root.Children.Add(status);

        Content = root;
    }

    private void Install()
    {
        try
        {
            var setupDir = AppContext.BaseDirectory;
            var sourceDir = Path.Combine(setupDir, "app");
            var sourceExe = Path.Combine(sourceDir, "Quick Text.exe");
            if (!File.Exists(sourceExe))
            {
                throw new InvalidOperationException("App-Payload fehlt. Erwartet wurde der Ordner 'app' neben Quick Text Setup.exe.");
            }

            var installDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "Quick Text");
            if (Directory.Exists(installDir)) Directory.Delete(installDir, true);
            CopyDirectory(sourceDir, installDir);

            var installedExe = Path.Combine(installDir, "Quick Text.exe");
            CreateShortcut(installedExe);
            ConfigureStartup(installedExe, startAtLogin.IsChecked == true);

            status.Text = $"Installiert nach {installDir}";
            if (launchAfterInstall.IsChecked == true)
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
}

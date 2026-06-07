using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Interop;
using QuickTextWindows.Services;

namespace QuickTextWindows;

public sealed class MainWindow : Window
{
    private readonly AppSettings settings = SettingsStore.Load();
    private readonly StackPanel content = new() { Margin = new Thickness(18) };
    private readonly TextBlock status = new() { Text = "Bereit", Margin = new Thickness(0, 8, 0, 8), Foreground = Brushes.DimGray };
    private AudioRecorder? recorder;
    private WorkflowType? activeType;
    private IntPtr pasteTarget;
    private bool processing;
    public event EventHandler? HideRequested;
    public bool IsConfigured => CredentialStore.IsConfigured || LocalTranscriptionService.IsInstalled;

    public void SetPasteTarget(IntPtr target)
    {
        if (target != IntPtr.Zero && target != new WindowInteropHelper(this).Handle) pasteTarget = target;
    }

    public MainWindow()
    {
        Title = "Quick Text";
        Width = 390; Height = 620; MinWidth = 370; MinHeight = 500;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Color.FromRgb(248, 248, 248));
        Closing += (_, e) => { e.Cancel = true; HideRequested?.Invoke(this, EventArgs.Empty); };
        Content = new ScrollViewer { Content = content, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        ShowMain();
    }

    private void ShowMain()
    {
        content.Children.Clear();
        content.Children.Add(new TextBlock { Text = "Quick Text", FontSize = 24, FontWeight = FontWeights.SemiBold });
        content.Children.Add(new TextBlock
        {
            Text = IsConfigured ? "Bereit" : "OpenAI API Key oder lokales Modell einrichten",
            Foreground = IsConfigured ? Brushes.SeaGreen : Brushes.DarkOrange, Margin = new Thickness(0, 2, 0, 14)
        });

        foreach (var type in WorkflowInfo.Main)
        {
            var button = new Button
            {
                Content = $"{WorkflowInfo.Name(type, settings)}\n{WorkflowInfo.Subtitle(type)}     {WorkflowInfo.Hotkey(type)}",
                HorizontalContentAlignment = HorizontalAlignment.Left, Padding = new Thickness(12), Margin = new Thickness(0, 3, 0, 3),
                IsEnabled = Available(type)
            };
            var captured = type;
            button.Click += (_, _) => StartWorkflow(captured);
            content.Children.Add(button);
        }

        var local = new CheckBox
        {
            Content = "Sicherer Lokaler Modus",
            IsChecked = settings.SecureLocalModeEnabled,
            Margin = new Thickness(4, 14, 0, 8),
            ToolTip = "Audio bleibt lokal; Schreib-Workflows sind pausiert."
        };
        local.Checked += (_, _) => { settings.SecureLocalModeEnabled = true; SaveAndRefresh(); };
        local.Unchecked += (_, _) => { settings.SecureLocalModeEnabled = false; SaveAndRefresh(); };
        content.Children.Add(local);
        content.Children.Add(status);

        var settingsButton = new Button { Content = "Einstellungen", Padding = new Thickness(8), Margin = new Thickness(0, 12, 0, 0) };
        settingsButton.Click += (_, _) => ShowSettings();
        content.Children.Add(settingsButton);
    }

    private bool Available(WorkflowType type) => type switch
    {
        WorkflowType.Transcription => settings.SecureLocalModeEnabled ? LocalTranscriptionService.IsInstalled : CredentialStore.IsConfigured,
        WorkflowType.LocalTranscription => LocalTranscriptionService.IsInstalled,
        _ => !settings.SecureLocalModeEnabled && CredentialStore.IsConfigured
    };

    public void HandleHotkey(WorkflowType type, bool down)
    {
        if (settings.HotkeyMode == HotkeyMode.Hold)
        {
            if (down) StartWorkflow(type, false);
            else if (activeType == type) StopWorkflow();
        }
        else if (down)
        {
            if (activeType == type) StopWorkflow();
            else StartWorkflow(type);
        }
    }

    public void StartWorkflow(WorkflowType type, bool show = true)
    {
        if (!Available(type) || processing) return;
        if (recorder?.IsRecording == true) recorder.Dispose();
        activeType = type;
        SetPasteTarget(PasteService.GetForegroundWindow());
        recorder = new AudioRecorder();
        try
        {
            recorder.Start();
            status.Text = $"{WorkflowInfo.Name(type, settings)}: Aufnahme läuft ...";
            if (show) { Show(); Activate(); }
        }
        catch (Exception ex) { status.Text = ex.Message; activeType = null; }
    }

    public async void StopWorkflow()
    {
        if (recorder?.IsRecording != true || activeType == null) return;
        var type = activeType.Value;
        var duration = recorder.Duration;
        var file = recorder.Stop();
        if (duration.TotalSeconds < .3) { FinishError("Keine Aufnahme erkannt."); return; }
        processing = true;
        status.Text = "Wird transkribiert ...";
        try
        {
            var local = type == WorkflowType.LocalTranscription || (type == WorkflowType.Transcription && settings.SecureLocalModeEnabled);
            var terms = duration.TotalSeconds >= .9 ? settings.TextImprovement.CustomTerms : [];
            var text = local
                ? await LocalTranscriptionService.Transcribe(file, settings.Language)
                : await OpenAIService.Transcribe(file, terms, settings.Language);
            text = text.Trim();
            if (string.IsNullOrWhiteSpace(text)) throw new InvalidOperationException("Keine Aufnahme erkannt.");

            status.Text = type switch
            {
                WorkflowType.TextImprover => "Text wird verbessert ...",
                WorkflowType.DampfAblassen => "Wird umformuliert ...",
                WorkflowType.EmojiText => "Emojis werden eingefügt ...",
                _ => "Fertig"
            };
            text = type switch
            {
                WorkflowType.TextImprover => await OpenAIService.Improve(text, settings),
                WorkflowType.DampfAblassen => await OpenAIService.Calm(text, settings),
                WorkflowType.EmojiText => await OpenAIService.Emojis(text, settings),
                _ => text
            };
            PasteService.Paste(text.Trim(), pasteTarget);
            status.Text = "Fertig. Text wurde kopiert und eingefügt.";
        }
        catch (Exception ex) { status.Text = ex.Message; }
        finally
        {
            try { File.Delete(file); } catch { }
            recorder.Dispose(); recorder = null; activeType = null; processing = false;
        }
    }

    public void CancelWorkflow()
    {
        if (recorder?.IsRecording == true) recorder.Dispose();
        recorder = null; activeType = null; processing = false; status.Text = "Abgebrochen.";
    }

    private void FinishError(string message)
    {
        recorder?.Dispose(); recorder = null; activeType = null; processing = false; status.Text = message;
    }

    private void ShowSettings()
    {
        content.Children.Clear();
        content.Children.Add(new TextBlock { Text = "Einstellungen", FontSize = 22, FontWeight = FontWeights.SemiBold });

        AddLabel("OpenAI API Key");
        var key = new PasswordBox { Margin = new Thickness(0, 4, 0, 4) };
        content.Children.Add(key);
        var saveKey = new Button { Content = CredentialStore.IsConfigured ? "API Key ändern" : "API Key speichern", Padding = new Thickness(8) };
        saveKey.Click += (_, _) =>
        {
            if (key.Password.StartsWith("sk-", StringComparison.Ordinal) && key.Password.Length >= 20)
            {
                CredentialStore.Save(key.Password); key.Clear(); status.Text = "API Key sicher gespeichert."; ShowSettings();
            }
            else MessageBox.Show("Bitte einen gültigen OpenAI API Key eingeben.");
        };
        content.Children.Add(saveKey);

        AddLabel("Modus und Hotkeys");
        var local = new CheckBox { Content = "Sicherer Lokaler Modus", IsChecked = settings.SecureLocalModeEnabled };
        local.Click += (_, _) => { settings.SecureLocalModeEnabled = local.IsChecked == true; SettingsStore.Save(settings); };
        content.Children.Add(local);
        var mode = new ComboBox { ItemsSource = Enum.GetValues<HotkeyMode>(), SelectedItem = settings.HotkeyMode, Margin = new Thickness(0, 6, 0, 4) };
        mode.SelectionChanged += (_, _) => { settings.HotkeyMode = (HotkeyMode)mode.SelectedItem; SettingsStore.Save(settings); };
        content.Children.Add(mode);
        content.Children.Add(new TextBlock { Text = string.Join("\n", WorkflowInfo.Main.Select(t => $"{WorkflowInfo.Hotkey(t)}  {WorkflowInfo.Name(t, settings)}")), Margin = new Thickness(0, 4, 0, 0) });

        AddLabel("Lokale Transkription");
        content.Children.Add(new TextBlock
        {
            Text = LocalTranscriptionService.IsInstalled
                ? "whisper.cpp ist installiert."
                : $"Lege whisper-cli.exe und ggml-small.bin hier ab:\n{AppPaths.Models}",
            TextWrapping = TextWrapping.Wrap
        });
        var openModels = new Button { Content = "Modellordner öffnen", Padding = new Thickness(8), Margin = new Thickness(0, 5, 0, 3) };
        openModels.Click += (_, _) => { Directory.CreateDirectory(AppPaths.Models); Process.Start("explorer.exe", AppPaths.Models); };
        content.Children.Add(openModels);
        var openGuide = new Button { Content = "Download-Anleitung öffnen", Padding = new Thickness(8) };
        openGuide.Click += (_, _) => Process.Start(new ProcessStartInfo("https://github.com/ggerganov/whisper.cpp") { UseShellExecute = true });
        content.Children.Add(openGuide);

        AddLabel("Anpassen");
        AddTextSetting("Name Quick Text+", settings.TextImprovement.CustomName, v => settings.TextImprovement.CustomName = v);
        AddTextSetting("Eigennamen / Begriffe (kommagetrennt)", string.Join(", ", settings.TextImprovement.CustomTerms),
            v => settings.TextImprovement.CustomTerms = v.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList());
        AddTextSetting("Kontext", settings.TextImprovement.Context, v => settings.TextImprovement.Context = v);
        AddTextSetting("Eigener Prompt Quick Text+", settings.TextImprovement.SystemPrompt, v => settings.TextImprovement.SystemPrompt = v, true);
        AddEnumSetting("Ton Quick Text+", settings.TextImprovement.Tone, v => settings.TextImprovement.Tone = v);
        AddTextSetting("Name Quick Text $%&!", settings.DampfAblassen.CustomName, v => settings.DampfAblassen.CustomName = v);
        AddTextSetting("Prompt Quick Text $%&!", settings.DampfAblassen.SystemPrompt, v => settings.DampfAblassen.SystemPrompt = v, true);
        AddTextSetting("Name Quick Text :)", settings.EmojiText.CustomName, v => settings.EmojiText.CustomName = v);
        AddEnumSetting("Emoji-Dichte", settings.EmojiText.EmojiDensity, v => settings.EmojiText.EmojiDensity = v);

        AddLabel("Windows");
        var startup = new CheckBox { Content = "Quick Text automatisch starten", IsChecked = StartupService.IsEnabled };
        startup.Click += (_, _) => StartupService.IsEnabled = startup.IsChecked == true;
        content.Children.Add(startup);

        var delete = new Button { Content = "Lokale Einstellungen und API Key löschen", Margin = new Thickness(0, 12, 0, 3), Padding = new Thickness(8) };
        delete.Click += (_, _) =>
        {
            CredentialStore.Delete();
            if (File.Exists(AppPaths.Settings)) File.Delete(AppPaths.Settings);
            MessageBox.Show("Lokale Einstellungen wurden gelöscht. Quick Text wird beendet.");
            System.Windows.Application.Current.Shutdown();
        };
        content.Children.Add(delete);
        var back = new Button { Content = "Zurück", Padding = new Thickness(8), Margin = new Thickness(0, 14, 0, 0) };
        back.Click += (_, _) => { SettingsStore.Save(settings); ShowMain(); };
        content.Children.Add(back);
    }

    private void AddLabel(string text) => content.Children.Add(new TextBlock { Text = text.ToUpperInvariant(), FontWeight = FontWeights.SemiBold, Foreground = Brushes.DimGray, Margin = new Thickness(0, 18, 0, 2) });

    private void AddTextSetting(string label, string value, Action<string> setter, bool multiline = false)
    {
        content.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 5, 0, 1) });
        var box = new TextBox
        {
            Text = value, AcceptsReturn = multiline, TextWrapping = TextWrapping.Wrap,
            MinHeight = multiline ? 72 : 0,
            VerticalScrollBarVisibility = multiline ? ScrollBarVisibility.Auto : ScrollBarVisibility.Disabled
        };
        box.LostFocus += (_, _) => { setter(box.Text); SettingsStore.Save(settings); };
        content.Children.Add(box);
    }

    private void AddEnumSetting<T>(string label, T value, Action<T> setter) where T : struct, Enum
    {
        content.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 5, 0, 1) });
        var box = new ComboBox { ItemsSource = Enum.GetValues<T>(), SelectedItem = value };
        box.SelectionChanged += (_, _) => { setter((T)box.SelectedItem); SettingsStore.Save(settings); };
        content.Children.Add(box);
    }

    private void SaveAndRefresh() { SettingsStore.Save(settings); ShowMain(); }
}

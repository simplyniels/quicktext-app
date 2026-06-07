using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using QuickTextWindows.Services;

namespace QuickTextWindows;

public sealed class MainWindow : Window
{
    private readonly AppSettings settings = SettingsStore.Load();
    private readonly StackPanel body = new() { Margin = new Thickness(24, 18, 24, 18) };
    private readonly TextBlock statusText = Text("Bereit", 20, FontWeights.Bold, Palette.Text);
    private readonly Border panel = new();
    private readonly ScrollViewer scroll = new();

    private AudioRecorder? recorder;
    private WorkflowType? activeType;
    private IntPtr pasteTarget;
    private bool processing;
    private int settingsTab;

    public event EventHandler? HideRequested;
    public bool IsConfigured => CredentialStore.IsConfigured || LocalTranscriptionService.IsInstalled;

    public MainWindow()
    {
        Title = "Quick Text";
        Width = 526;
        Height = 657;
        MinWidth = 526;
        MinHeight = 657;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Palette.WindowBackground;
        Closing += (_, e) => { e.Cancel = true; HideRequested?.Invoke(this, EventArgs.Empty); };

        panel.CornerRadius = new CornerRadius(26);
        panel.BorderBrush = Palette.Border;
        panel.BorderThickness = new Thickness(1);
        panel.Background = Palette.Panel;
        panel.Effect = new System.Windows.Media.Effects.DropShadowEffect
        {
            Color = Color.FromRgb(30, 70, 90),
            BlurRadius = 26,
            ShadowDepth = 8,
            Opacity = 0.18
        };

        scroll.Content = body;
        scroll.VerticalScrollBarVisibility = ScrollBarVisibility.Disabled;
        scroll.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
        scroll.BorderThickness = new Thickness(0);
        panel.Child = scroll;
        Content = new Grid { Margin = new Thickness(18), Children = { panel } };
        ShowMain();
    }

    public void SetPasteTarget(IntPtr target)
    {
        if (target != IntPtr.Zero && target != new WindowInteropHelper(this).Handle) pasteTarget = target;
    }

    private void ShowMain()
    {
        scroll.VerticalScrollBarVisibility = ScrollBarVisibility.Disabled;
        body.Children.Clear();
        AddMainHeader();
        AddModePanel();
        AddWorkflowRows();
        AddFooter();
    }

    private void AddMainHeader()
    {
        var header = new Grid { Margin = new Thickness(0, 4, 0, 24) };
        header.ColumnDefinitions.Add(new ColumnDefinition());
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var title = Text("Quick Text", 16, FontWeights.SemiBold, Palette.Muted);
        header.Children.Add(title);

        var gear = GhostButton("Einstellungen", "⚙");
        gear.Click += (_, _) => { settingsTab = defaultSettingsTab; ShowSettings(); };
        Grid.SetColumn(gear, 1);
        header.Children.Add(gear);
        body.Children.Add(header);

        var status = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 2, 0, 4)
        };
        status.Children.Add(new Border
        {
            Width = 11,
            Height = 11,
            CornerRadius = new CornerRadius(7),
            Background = Palette.Success,
            Margin = new Thickness(0, 7, 10, 0)
        });
        var headerStatus = Text(processing
            ? "Arbeitet"
            : recorder?.IsRecording == true ? "Aufnahme" : "Bereit", 20, FontWeights.Bold, Palette.Text);
        status.Children.Add(headerStatus);
        body.Children.Add(status);
    }

    private void AddModePanel()
    {
        var card = Card(new Thickness(0, 18, 0, 18), 14);
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var localInstalled = LocalTranscriptionService.IsInstalled;
        var secure = settings.SecureLocalModeEnabled;
        var icon = IconBox(secure ? "" : "", secure ? Palette.Success : Palette.Accent, 34);
        Grid.SetColumn(icon, 0);
        grid.Children.Add(icon);

        var text = new StackPanel { Margin = new Thickness(12, 0, 12, 0) };
        text.Children.Add(Text(secure ? "Sicherer lokaler Modus" : "Online Whisper", 16, FontWeights.Bold, Palette.Text));
        text.Children.Add(Text(
            secure
                ? localInstalled ? "Lokal mit whisper.cpp." : "Lokales Modell fehlt."
                : "Quick Text nutzt gerade die Server-Transkription.",
            13,
            FontWeights.Medium,
            Palette.Muted));
        if (secure)
        {
            text.Children.Add(Text("Modell: whisper.cpp", 12, FontWeights.SemiBold, Palette.Muted, new Thickness(0, 8, 0, 0)));
        }
        Grid.SetColumn(text, 1);
        grid.Children.Add(text);

        var toggle = TogglePill(secure);
        toggle.MouseLeftButtonUp += (_, _) =>
        {
            settings.SecureLocalModeEnabled = !settings.SecureLocalModeEnabled;
            SettingsStore.Save(settings);
            ShowMain();
        };
        Grid.SetColumn(toggle, 2);
        grid.Children.Add(toggle);
        card.Child = grid;
        body.Children.Add(card);
    }

    private void AddWorkflowRows()
    {
        foreach (var type in WorkflowInfo.Main)
        {
            var enabled = Available(type);
            var row = WorkflowRow(type, enabled);
            row.MouseLeftButtonUp += (_, _) =>
            {
                if (enabled) StartWorkflow(type);
            };
            body.Children.Add(row);
        }
    }

    private Border WorkflowRow(WorkflowType type, bool enabled)
    {
        var row = new Border
        {
            CornerRadius = new CornerRadius(14),
            Background = Brushes.Transparent,
            Padding = new Thickness(4, 8, 4, 8),
            Opacity = enabled ? 1.0 : 0.26,
            Cursor = enabled ? Cursors.Hand : Cursors.Arrow
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var accent = type switch
        {
            WorkflowType.Transcription => Palette.Text,
            WorkflowType.TextImprover => Palette.Accent,
            WorkflowType.DampfAblassen => Palette.Fire,
            WorkflowType.EmojiText => Palette.Text,
            _ => Palette.Success
        };
        grid.Children.Add(IconBox(IconFor(type), accent, 48));

        var copy = new StackPanel { Margin = new Thickness(14, 2, 8, 0) };
        copy.Children.Add(Text(WorkflowInfo.Name(type, settings), 17, FontWeights.Bold, Palette.Text));
        copy.Children.Add(Text(SubtitleFor(type), 13.5, FontWeights.Medium, Palette.Subtitle));
        Grid.SetColumn(copy, 1);
        grid.Children.Add(copy);

        var badges = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        foreach (var key in WorkflowInfo.Hotkey(type).Split(" + "))
        {
            badges.Children.Add(KeyBadge(key));
        }
        Grid.SetColumn(badges, 2);
        grid.Children.Add(badges);

        row.Child = grid;
        row.MouseEnter += (_, _) => { if (enabled) row.Background = Palette.RowHover; };
        row.MouseLeave += (_, _) => row.Background = Brushes.Transparent;
        return row;
    }

    private string SubtitleFor(WorkflowType type)
    {
        if (settings.SecureLocalModeEnabled)
        {
            return type == WorkflowType.Transcription
                ? LocalTranscriptionService.IsInstalled ? "Lokal: whisper.cpp." : "Lokales Modell fehlt."
                : "Im lokalen Modus pausiert.";
        }

        return type == WorkflowType.Transcription
            ? "Online: Whisper über Server."
            : WorkflowInfo.Subtitle(type);
    }

    private void AddFooter()
    {
        body.Children.Add(statusText);
        statusText.Margin = new Thickness(0, 18, 0, 6);
        statusText.FontSize = 12;
        statusText.FontWeight = FontWeights.SemiBold;
        statusText.Foreground = Palette.Muted;
        statusText.HorizontalAlignment = HorizontalAlignment.Center;
        statusText.Text = recorder?.IsRecording == true
            ? "Loslassen oder erneut drücken zum Stoppen"
            : string.IsNullOrWhiteSpace(statusText.Text) || statusText.Text is "Bereit" or "Aufnahme" or "Arbeitet"
                ? "Beenden"
                : statusText.Text;
    }

    private int defaultSettingsTab => IsConfigured ? 0 : 1;

    private void ShowSettings()
    {
        scroll.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        body.Children.Clear();
        AddSettingsHeader();
        AddSegmentedTabs();

        if (settingsTab == 0)
        {
            AddCustomizeSettings();
        }
        else
        {
            AddAccessSettings();
        }
    }

    private void AddSettingsHeader()
    {
        var header = new Grid { Margin = new Thickness(0, 2, 0, 18) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition());
        var back = TextButton("‹ Zurück");
        back.Click += (_, _) => ShowMain();
        header.Children.Add(back);
        var title = Text("Einstellungen", 18, FontWeights.Bold, Palette.Text);
        title.HorizontalAlignment = HorizontalAlignment.Center;
        Grid.SetColumn(title, 1);
        header.Children.Add(title);
        body.Children.Add(header);
    }

    private void AddSegmentedTabs()
    {
        var segment = new Border
        {
            CornerRadius = new CornerRadius(10),
            Background = Palette.SegmentBackground,
            Padding = new Thickness(3),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 24)
        };
        var grid = new Grid { Width = 220 };
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.Children.Add(SegmentButton("Anpassen", 0));
        var access = SegmentButton("Zugang", 1);
        Grid.SetColumn(access, 1);
        grid.Children.Add(access);
        segment.Child = grid;
        body.Children.Add(segment);
    }

    private Button SegmentButton(string label, int tab)
    {
        var button = ButtonShell(label, settingsTab == tab ? Palette.Accent : Brushes.Transparent, settingsTab == tab ? Brushes.White : Palette.Text);
        button.FontSize = 16;
        button.FontWeight = settingsTab == tab ? FontWeights.Bold : FontWeights.Medium;
        button.Click += (_, _) => { settingsTab = tab; ShowSettings(); };
        return button;
    }

    private void AddCustomizeSettings()
    {
        AddSectionTitle("Sicherer lokaler Modus");
        AddSettingRow("Sicherer Lokaler Modus", TogglePill(settings.SecureLocalModeEnabled, () =>
        {
            settings.SecureLocalModeEnabled = !settings.SecureLocalModeEnabled;
            SettingsStore.Save(settings);
            ShowSettings();
        }));

        var state = LocalTranscriptionService.IsInstalled
            ? "whisper.cpp ist installiert."
            : $"whisper-cli.exe und ggml-small.bin fehlen:\n{AppPaths.Models}";
        body.Children.Add(Text(state, 13, FontWeights.Medium, LocalTranscriptionService.IsInstalled ? Palette.Success : Palette.Muted));

        var openModels = SecondaryButton("Modellordner öffnen");
        openModels.Click += (_, _) => { Directory.CreateDirectory(AppPaths.Models); Process.Start("explorer.exe", AppPaths.Models); };
        body.Children.Add(openModels);
        var openGuide = SecondaryButton("whisper.cpp Anleitung öffnen");
        openGuide.Click += (_, _) => Process.Start(new ProcessStartInfo("https://github.com/ggerganov/whisper.cpp") { UseShellExecute = true });
        body.Children.Add(openGuide);

        AddSectionTitle("Tastenkürzel");
        foreach (var type in WorkflowInfo.Main)
        {
            var line = new Grid { Margin = new Thickness(0, 4, 0, 0) };
            line.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(150) });
            line.ColumnDefinitions.Add(new ColumnDefinition());
            line.Children.Add(Text(WorkflowInfo.Hotkey(type), 14, FontWeights.Medium, Palette.Mono));
            var name = Text(WorkflowInfo.Name(type, settings), 14, FontWeights.Bold, Palette.Text);
            Grid.SetColumn(name, 1);
            line.Children.Add(name);
            body.Children.Add(line);
        }

        AddSectionTitle("Modus");
        AddModeButtons();

        AddSectionTitle("Quick Text+");
        AddTextSetting("Eigener Name", settings.TextImprovement.CustomName, v => settings.TextImprovement.CustomName = v);
        AddToneButtons();
        AddTextSetting("Eigene Anweisung", settings.TextImprovement.SystemPrompt, v => settings.TextImprovement.SystemPrompt = v, true);
        AddTextSetting("Kontext", settings.TextImprovement.Context, v => settings.TextImprovement.Context = v);
        AddTextSetting("Eigennamen / Begriffe", string.Join(", ", settings.TextImprovement.CustomTerms),
            v => settings.TextImprovement.CustomTerms = v.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList());

        AddSectionTitle("Quick Text $%&!");
        AddTextSetting("Eigener Name", settings.DampfAblassen.CustomName, v => settings.DampfAblassen.CustomName = v);
        AddTextSetting("Eigene Anweisung", settings.DampfAblassen.SystemPrompt, v => settings.DampfAblassen.SystemPrompt = v, true);

        AddSectionTitle("Quick Text :)");
        AddTextSetting("Eigener Name", settings.EmojiText.CustomName, v => settings.EmojiText.CustomName = v);
        AddEnumSetting("Emoji-Dichte", settings.EmojiText.EmojiDensity, v => settings.EmojiText.EmojiDensity = v);
    }

    private void AddAccessSettings()
    {
        AddSectionTitle("OpenAI API Key");
        var keyCard = Card(new Thickness(0, 0, 0, 14), 12);
        var keyStack = new StackPanel();
        keyStack.Children.Add(Text(
            CredentialStore.IsConfigured ? "API Key ist sicher gespeichert." : "API Key lokal speichern.",
            13,
            FontWeights.Bold,
            CredentialStore.IsConfigured ? Palette.Success : Palette.Text));
        var key = new PasswordBox { Margin = new Thickness(0, 10, 0, 8), Padding = new Thickness(8), FontSize = 13 };
        keyStack.Children.Add(key);
        var saveKey = PrimaryButton(CredentialStore.IsConfigured ? "API Key ändern" : "API Key speichern");
        saveKey.Click += (_, _) =>
        {
            if (key.Password.StartsWith("sk-", StringComparison.Ordinal) && key.Password.Length >= 20)
            {
                CredentialStore.Save(key.Password);
                key.Clear();
                ShowSettings();
            }
            else MessageBox.Show("Bitte einen gültigen OpenAI API Key eingeben.");
        };
        keyStack.Children.Add(saveKey);
        keyCard.Child = keyStack;
        body.Children.Add(keyCard);

        AddSectionTitle("Beim Anmelden");
        AddSettingRow("Quick Text automatisch starten", TogglePill(StartupService.IsEnabled, () =>
        {
            StartupService.IsEnabled = !StartupService.IsEnabled;
            ShowSettings();
        }));

        AddSectionTitle("Windows");
        body.Children.Add(Text("Für direktes Einfügen nutzt Quick Text die Zwischenablage und simuliert Ctrl+V.", 13, FontWeights.Medium, Palette.Muted));

        var delete = SecondaryButton("Lokale Einstellungen und API Key löschen");
        delete.Margin = new Thickness(0, 16, 0, 0);
        delete.Click += (_, _) =>
        {
            CredentialStore.Delete();
            if (File.Exists(AppPaths.Settings)) File.Delete(AppPaths.Settings);
            MessageBox.Show("Lokale Einstellungen wurden gelöscht. Quick Text wird beendet.");
            System.Windows.Application.Current.Shutdown();
        };
        body.Children.Add(delete);
    }

    private void AddModeButtons()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 6, 0, 0) };
        row.Children.Add(PillChoice("Halten", settings.HotkeyMode == HotkeyMode.Hold, () =>
        {
            settings.HotkeyMode = HotkeyMode.Hold;
            SettingsStore.Save(settings);
            ShowSettings();
        }));
        row.Children.Add(PillChoice("Drücken", settings.HotkeyMode == HotkeyMode.Toggle, () =>
        {
            settings.HotkeyMode = HotkeyMode.Toggle;
            SettingsStore.Save(settings);
            ShowSettings();
        }));
        body.Children.Add(row);
    }

    private void AddToneButtons()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 6, 0, 10) };
        row.Children.Add(PillChoice("Formell", settings.TextImprovement.Tone == TextTone.Formal, () =>
        {
            settings.TextImprovement.Tone = TextTone.Formal;
            SettingsStore.Save(settings);
            ShowSettings();
        }));
        row.Children.Add(PillChoice("Neutral", settings.TextImprovement.Tone == TextTone.Neutral, () =>
        {
            settings.TextImprovement.Tone = TextTone.Neutral;
            SettingsStore.Save(settings);
            ShowSettings();
        }));
        row.Children.Add(PillChoice("Locker", settings.TextImprovement.Tone == TextTone.Casual, () =>
        {
            settings.TextImprovement.Tone = TextTone.Casual;
            SettingsStore.Save(settings);
            ShowSettings();
        }));
        body.Children.Add(row);
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
            statusText.Text = $"{WorkflowInfo.Name(type, settings)}: Aufnahme läuft ...";
            if (show) { Show(); Activate(); }
            ShowMain();
        }
        catch (Exception ex) { statusText.Text = ex.Message; activeType = null; ShowMain(); }
    }

    public async void StopWorkflow()
    {
        if (recorder?.IsRecording != true || activeType == null) return;
        var type = activeType.Value;
        var duration = recorder.Duration;
        var file = recorder.Stop();
        if (duration.TotalSeconds < .3) { FinishError("Keine Aufnahme erkannt."); return; }
        processing = true;
        statusText.Text = "Wird transkribiert ...";
        ShowMain();
        try
        {
            var local = type == WorkflowType.LocalTranscription || (type == WorkflowType.Transcription && settings.SecureLocalModeEnabled);
            var terms = duration.TotalSeconds >= .9 ? settings.TextImprovement.CustomTerms : [];
            var text = local
                ? await LocalTranscriptionService.Transcribe(file, settings.Language)
                : await OpenAIService.Transcribe(file, terms, settings.Language);
            text = text.Trim();
            if (string.IsNullOrWhiteSpace(text)) throw new InvalidOperationException("Keine Aufnahme erkannt.");

            statusText.Text = type switch
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
            statusText.Text = "Fertig. Text wurde kopiert und eingefügt.";
        }
        catch (Exception ex) { statusText.Text = ex.Message; }
        finally
        {
            try { File.Delete(file); } catch { }
            recorder.Dispose(); recorder = null; activeType = null; processing = false;
            ShowMain();
        }
    }

    public void CancelWorkflow()
    {
        if (recorder?.IsRecording == true) recorder.Dispose();
        recorder = null; activeType = null; processing = false; statusText.Text = "Abgebrochen.";
        ShowMain();
    }

    private void FinishError(string message)
    {
        recorder?.Dispose(); recorder = null; activeType = null; processing = false; statusText.Text = message; ShowMain();
    }

    private static Border Card(Thickness margin, double radius) => new()
    {
        CornerRadius = new CornerRadius(radius),
        Background = Palette.Card,
        BorderBrush = Palette.Border,
        BorderThickness = new Thickness(1),
        Padding = new Thickness(14),
        Margin = margin
    };

    private static Border IconBox(string glyph, Brush color, double size)
    {
        var box = new Border
        {
            Width = size,
            Height = size,
            CornerRadius = new CornerRadius(12),
            Background = Palette.IconTile,
            Child = new TextBlock
            {
                Text = glyph,
                FontFamily = new FontFamily("Segoe MDL2 Assets"),
                Foreground = color,
                FontSize = size * 0.45,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        };
        return box;
    }

    private static Border KeyBadge(string text) => new()
    {
        CornerRadius = new CornerRadius(7),
        Background = Palette.KeyBackground,
        BorderBrush = Palette.KeyBorder,
        BorderThickness = new Thickness(1),
        Padding = new Thickness(9, 5, 9, 5),
        Margin = new Thickness(4, 0, 0, 0),
        Child = Text(text.Replace("Win", "⊞"), 12, FontWeights.Bold, Palette.Text)
    };

    private static Button GhostButton(string tooltip, string glyph)
    {
        var button = ButtonShell(glyph, Brushes.Transparent, Palette.Muted);
        button.ToolTip = tooltip;
        button.FontSize = 21;
        button.Width = 34;
        return button;
    }

    private static Button TextButton(string label)
    {
        var button = ButtonShell(label, Brushes.Transparent, Palette.Muted);
        button.FontSize = 16;
        button.FontWeight = FontWeights.Medium;
        return button;
    }

    private static Button PrimaryButton(string label) => ButtonShell(label, Palette.Accent, Brushes.White);

    private static Button SecondaryButton(string label) => ButtonShell(label, Palette.SegmentBackground, Palette.Text);

    private static Button ButtonShell(string label, Brush background, Brush foreground) => new()
    {
        Content = label,
        Background = background,
        Foreground = foreground,
        BorderBrush = Brushes.Transparent,
        Padding = new Thickness(12, 7, 12, 7),
        Margin = new Thickness(0, 6, 0, 0),
        FontWeight = FontWeights.SemiBold,
        Cursor = Cursors.Hand
    };

    private static Border TogglePill(bool isOn, Action? action = null)
    {
        var pill = new Border
        {
            Width = 58,
            Height = 32,
            CornerRadius = new CornerRadius(18),
            Background = isOn ? Palette.Accent : Palette.SegmentBackground,
            Cursor = Cursors.Hand,
            Child = new Border
            {
                Width = 25,
                Height = 25,
                CornerRadius = new CornerRadius(14),
                Background = Brushes.White,
                HorizontalAlignment = isOn ? HorizontalAlignment.Right : HorizontalAlignment.Left,
                Margin = new Thickness(4)
            }
        };
        if (action != null) pill.MouseLeftButtonUp += (_, _) => action();
        return pill;
    }

    private Border PillChoice(string label, bool selected, Action action)
    {
        var pill = new Border
        {
            CornerRadius = new CornerRadius(9),
            Background = selected ? Palette.Accent : Palette.SegmentBackground,
            Padding = new Thickness(14, 8, 14, 8),
            Margin = new Thickness(0, 0, 6, 0),
            Cursor = Cursors.Hand,
            Child = Text(label, 15, selected ? FontWeights.Bold : FontWeights.Medium, selected ? Brushes.White : Palette.Text)
        };
        pill.MouseLeftButtonUp += (_, _) => action();
        return pill;
    }

    private void AddSettingRow(string label, UIElement control)
    {
        var row = new Grid { Margin = new Thickness(0, 4, 0, 10) };
        row.ColumnDefinitions.Add(new ColumnDefinition());
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.Children.Add(Text(label, 16, FontWeights.Medium, Palette.Text));
        Grid.SetColumn(control, 1);
        row.Children.Add(control);
        body.Children.Add(row);
    }

    private void AddSectionTitle(string label)
    {
        body.Children.Add(Text(label.ToUpperInvariant(), 13, FontWeights.Bold, Palette.Section, new Thickness(0, 22, 0, 10)));
    }

    private void AddTextSetting(string label, string value, Action<string> setter, bool multiline = false)
    {
        body.Children.Add(Text(label, 13.5, FontWeights.Medium, Palette.Muted, new Thickness(0, 8, 0, 5)));
        var box = new TextBox
        {
            Text = value,
            AcceptsReturn = multiline,
            TextWrapping = TextWrapping.Wrap,
            MinHeight = multiline ? 92 : 0,
            Padding = new Thickness(12),
            BorderBrush = Palette.Border,
            Background = Palette.Input,
            FontSize = 14,
            VerticalScrollBarVisibility = multiline ? ScrollBarVisibility.Auto : ScrollBarVisibility.Disabled
        };
        box.LostFocus += (_, _) => { setter(box.Text); SettingsStore.Save(settings); };
        body.Children.Add(box);
    }

    private void AddEnumSetting<T>(string label, T value, Action<T> setter) where T : struct, Enum
    {
        body.Children.Add(Text(label, 13.5, FontWeights.Medium, Palette.Muted, new Thickness(0, 8, 0, 5)));
        var box = new ComboBox
        {
            ItemsSource = Enum.GetValues<T>(),
            SelectedItem = value,
            Padding = new Thickness(8),
            BorderBrush = Palette.Border,
            Background = Palette.Input,
            FontSize = 14
        };
        box.SelectionChanged += (_, _) => { setter((T)box.SelectedItem); SettingsStore.Save(settings); };
        body.Children.Add(box);
    }

    private static string IconFor(WorkflowType type) => type switch
    {
        WorkflowType.Transcription => "",
        WorkflowType.TextImprover => "",
        WorkflowType.DampfAblassen => "",
        WorkflowType.EmojiText => "",
        WorkflowType.LocalTranscription => "",
        _ => ""
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

    private static class Palette
    {
        public static readonly Brush WindowBackground = new LinearGradientBrush(
            Color.FromRgb(31, 151, 204),
            Color.FromRgb(133, 224, 238),
            90);
        public static readonly Brush Panel = new SolidColorBrush(Color.FromRgb(199, 242, 248));
        public static readonly Brush Card = new SolidColorBrush(Color.FromArgb(88, 160, 217, 228));
        public static readonly Brush RowHover = new SolidColorBrush(Color.FromArgb(70, 255, 255, 255));
        public static readonly Brush IconTile = new SolidColorBrush(Color.FromArgb(76, 82, 177, 214));
        public static readonly Brush Border = new SolidColorBrush(Color.FromArgb(72, 58, 116, 137));
        public static readonly Brush SegmentBackground = new SolidColorBrush(Color.FromArgb(94, 100, 177, 203));
        public static readonly Brush KeyBackground = new SolidColorBrush(Color.FromArgb(58, 42, 131, 184));
        public static readonly Brush KeyBorder = new SolidColorBrush(Color.FromArgb(100, 31, 105, 150));
        public static readonly Brush Input = new SolidColorBrush(Color.FromArgb(78, 255, 255, 255));
        public static readonly Brush Accent = new SolidColorBrush(Color.FromRgb(0, 115, 255));
        public static readonly Brush Success = new SolidColorBrush(Color.FromRgb(43, 193, 80));
        public static readonly Brush Fire = new SolidColorBrush(Color.FromRgb(12, 88, 132));
        public static readonly Brush Text = new SolidColorBrush(Color.FromRgb(37, 58, 67));
        public static readonly Brush Subtitle = new SolidColorBrush(Color.FromRgb(24, 83, 118));
        public static readonly Brush Muted = new SolidColorBrush(Color.FromRgb(74, 112, 128));
        public static readonly Brush Section = new SolidColorBrush(Color.FromRgb(61, 104, 123));
        public static readonly Brush Mono = new SolidColorBrush(Color.FromRgb(47, 102, 128));
    }
}

using System.Text.Json.Serialization;

namespace QuickTextWindows;

public enum WorkflowType { Transcription, LocalTranscription, TextImprover, DampfAblassen, EmojiText }
public enum HotkeyMode { Hold, Toggle }
public enum TextTone { Formal, Neutral, Casual }
public enum EmojiDensity { Wenig, Mittel, Viel }

public static class WorkflowInfo
{
    public static readonly WorkflowType[] Main =
        [WorkflowType.Transcription, WorkflowType.TextImprover, WorkflowType.DampfAblassen, WorkflowType.EmojiText];

    public static string Name(WorkflowType type, AppSettings? settings = null) => type switch
    {
        WorkflowType.Transcription => "Quick Text",
        WorkflowType.LocalTranscription => "Quick Text Lokal",
        WorkflowType.TextImprover => Custom(settings?.TextImprovement.CustomName, "Quick Text+"),
        WorkflowType.DampfAblassen => Custom(settings?.DampfAblassen.CustomName, "Quick Text $%&!"),
        WorkflowType.EmojiText => Custom(settings?.EmojiText.CustomName, "Quick Text :)"),
        _ => type.ToString()
    };

    public static string Subtitle(WorkflowType type) => type switch
    {
        WorkflowType.Transcription => "Sprache rein. Text raus.",
        WorkflowType.LocalTranscription => "Nur lokal. Kein Server.",
        WorkflowType.TextImprover => "Geschrieben sprechen.",
        WorkflowType.DampfAblassen => "Frust rein. Entspannt raus.",
        WorkflowType.EmojiText => "Text rein. Emojis dazu.",
        _ => ""
    };

    public static string Hotkey(WorkflowType type) => type switch
    {
        WorkflowType.Transcription => "Win + Shift",
        WorkflowType.LocalTranscription => "Win + Shift + Ctrl",
        WorkflowType.TextImprover => "Win + Ctrl",
        WorkflowType.DampfAblassen => "Win + Alt",
        WorkflowType.EmojiText => "Win + Ctrl + Alt",
        _ => ""
    };

    private static string Custom(string? value, string fallback) =>
        string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
}

public sealed class AppSettings
{
    public HotkeyMode HotkeyMode { get; set; } = HotkeyMode.Hold;
    public bool HasSeenOnboarding { get; set; }
    public bool SecureLocalModeEnabled { get; set; }
    public string Language { get; set; } = "de";
    public TextImprovementSettings TextImprovement { get; set; } = new();
    public DampfAblassenSettings DampfAblassen { get; set; } = new();
    public EmojiTextSettings EmojiText { get; set; } = new();
}

public sealed class TextImprovementSettings
{
    public string SystemPrompt { get; set; } = "";
    public List<string> CustomTerms { get; set; } = [];
    public string Context { get; set; } = "";
    public TextTone Tone { get; set; } = TextTone.Neutral;
    public string CustomName { get; set; } = "";
}

public sealed class DampfAblassenSettings
{
    public string SystemPrompt { get; set; } =
        "Du erhältst ein emotional gesprochenes Transkript. Erkenne zuerst das eigentliche Ziel, Anliegen und den wahren Frust der Person. Formuliere daraus eine klare, respektvolle und wirksame Nachricht, mit der die Person ihr Ziel eher erreicht. Bewahre relevante Fakten, konkrete Probleme, Grenzen, Erwartungen und die nötige Dringlichkeit. Entferne Beleidigungen, Drohungen, Sarkasmus, Unterstellungen und unnötige Eskalation. Wenn mehrere Vorwürfe genannt werden, verdichte sie auf die entscheidenden Kernpunkte. Der Ton soll ruhig, menschlich, bestimmt und lösungsorientiert sein. Gib NUR die fertige Nachricht zurück.";
    public string CustomName { get; set; } = "";
}

public sealed class EmojiTextSettings
{
    public EmojiDensity EmojiDensity { get; set; } = EmojiDensity.Mittel;
    public string CustomName { get; set; } = "";
}

using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace QuickTextWindows.Services;

public static class OpenAIService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(60) };

    public static async Task<string> Transcribe(string audioPath, IEnumerable<string> terms, string language)
    {
        using var form = new MultipartFormDataContent();
        await using var stream = File.OpenRead(audioPath);
        var file = new StreamContent(stream);
        file.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        form.Add(file, "file", "audio.wav");
        form.Add(new StringContent("whisper-1"), "model");
        form.Add(new StringContent("text"), "response_format");
        if (terms.Any()) form.Add(new StringContent($"Eigennamen und Begriffe: {string.Join(", ", terms)}"), "prompt");
        if (!string.IsNullOrWhiteSpace(language)) form.Add(new StringContent(language.Trim()), "language");
        using var request = Request(HttpMethod.Post, "https://api.openai.com/v1/audio/transcriptions", form);
        using var response = await Http.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException(ApiError(body, response.StatusCode.ToString()));
        return body.Trim();
    }

    public static Task<string> Improve(string text, AppSettings settings) =>
        Complete(text, BuildImprovementPrompt(settings.TextImprovement), "gpt-4o-mini", .3);
    public static Task<string> Calm(string text, AppSettings settings) =>
        Complete(text, settings.DampfAblassen.SystemPrompt, "gpt-4o", .4);
    public static Task<string> Emojis(string text, AppSettings settings) =>
        Complete(text, BuildEmojiPrompt(settings.EmojiText.EmojiDensity), "gpt-4o-mini", .3);

    private static async Task<string> Complete(string text, string prompt, string model, double temperature)
    {
        var payload = JsonSerializer.Serialize(new
        {
            model, temperature,
            messages = new[] { new { role = "system", content = prompt }, new { role = "user", content = text } }
        });
        using var request = Request(HttpMethod.Post, "https://api.openai.com/v1/chat/completions",
            new StringContent(payload, Encoding.UTF8, "application/json"));
        using var response = await Http.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException(ApiError(body, response.StatusCode.ToString()));
        using var json = JsonDocument.Parse(body);
        return json.RootElement.GetProperty("choices")[0].GetProperty("message").GetProperty("content").GetString()?.Trim()
            ?? throw new InvalidOperationException("Keine Antwort erhalten.");
    }

    private static HttpRequestMessage Request(HttpMethod method, string url, HttpContent content)
    {
        var key = CredentialStore.Load() ?? throw new InvalidOperationException("OpenAI API Key fehlt. Bitte in den Einstellungen hinterlegen.");
        var request = new HttpRequestMessage(method, url) { Content = content };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        return request;
    }

    private static string ApiError(string body, string fallback)
    {
        try { return JsonDocument.Parse(body).RootElement.GetProperty("error").GetProperty("message").GetString() ?? fallback; }
        catch { return fallback; }
    }

    private static string BuildImprovementPrompt(TextImprovementSettings settings)
    {
        var prompt = string.IsNullOrWhiteSpace(settings.SystemPrompt)
            ? "Du bist ein Lektor und Schreibassistent. Korrigiere Rechtschreibung und Grammatik, verbessere Formulierung und Lesefluss, behalte die Bedeutung bei und gib NUR den verbesserten Text zurück."
            : settings.SystemPrompt;
        prompt += settings.Tone switch { TextTone.Formal => "\nVerwende einen formellen, professionellen Ton.", TextTone.Casual => "\nVerwende einen lockeren, natürlichen Ton.", _ => "\nVerwende einen neutralen, klaren Ton." };
        if (settings.CustomTerms.Count > 0) prompt += $"\nEigennamen und Fachbegriffe müssen exakt so geschrieben werden: {string.Join(", ", settings.CustomTerms)}";
        if (!string.IsNullOrWhiteSpace(settings.Context)) prompt += $"\nKontext: {settings.Context}";
        return prompt;
    }

    private static string BuildEmojiPrompt(EmojiDensity density) =>
        $"Du erhältst ein gesprochenes Transkript. Gib den Text möglichst originalgetreu zurück, aber füge passende Emojis ein. {(density == EmojiDensity.Wenig ? "Maximal 1-2 pro Absatz." : density == EmojiDensity.Viel ? "Gerne mehrere pro Satz." : "Etwa alle 1-2 Sätze.")} Korrigiere offensichtliche Fehler. Gib NUR den Text mit Emojis zurück.";
}

public static class LocalTranscriptionService
{
    public static bool IsInstalled => File.Exists(AppPaths.WhisperExe) && File.Exists(AppPaths.WhisperModel);

    public static async Task<string> Transcribe(string audioPath, string language)
    {
        if (!IsInstalled) throw new InvalidOperationException($"Lokale Transkription fehlt. Lege whisper-cli.exe und ggml-small.bin unter {AppPaths.Models} ab.");
        var output = Path.Combine(Path.GetTempPath(), $"quicktext-{Guid.NewGuid():N}");
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = AppPaths.WhisperExe,
            Arguments = $"-m \"{AppPaths.WhisperModel}\" -f \"{audioPath}\" -l {language} -otxt -of \"{output}\"",
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true
        }) ?? throw new InvalidOperationException("whisper-cli.exe konnte nicht gestartet werden.");
        await process.WaitForExitAsync();
        var resultPath = output + ".txt";
        if (process.ExitCode != 0 || !File.Exists(resultPath)) throw new InvalidOperationException(await process.StandardError.ReadToEndAsync());
        var text = (await File.ReadAllTextAsync(resultPath)).Trim();
        File.Delete(resultPath);
        return text;
    }
}

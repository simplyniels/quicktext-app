using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace QuickTextWindows.Services;

public static class AppPaths
{
    public static string Root => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Quick Text");
    public static string Settings => Path.Combine(Root, "settings.json");
    public static string Models => Path.Combine(Root, "models", "whisper.cpp");
    public static string WhisperExe => Path.Combine(Models, "whisper-cli.exe");
    public static string WhisperModel => Path.Combine(Models, "ggml-small.bin");
}

public static class SettingsStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true, Converters = { new JsonStringEnumConverter() } };

    public static AppSettings Load()
    {
        try
        {
            return File.Exists(AppPaths.Settings)
                ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(AppPaths.Settings), Options) ?? new()
                : new();
        }
        catch { return new(); }
    }

    public static void Save(AppSettings settings)
    {
        Directory.CreateDirectory(AppPaths.Root);
        File.WriteAllText(AppPaths.Settings, JsonSerializer.Serialize(settings, Options));
    }
}

public static class CredentialStore
{
    private const string Target = "app.quicktext.preview.credentials/openAIAPIKey";
    private const int Generic = 1;
    private const int PersistLocalMachine = 2;

    public static bool IsConfigured => !string.IsNullOrWhiteSpace(Load());

    public static void Save(string value)
    {
        var bytes = Encoding.Unicode.GetBytes(value);
        var pointer = Marshal.AllocCoTaskMem(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, pointer, bytes.Length);
            var credential = new Credential
            {
                Type = Generic, TargetName = Target, CredentialBlobSize = (uint)bytes.Length,
                CredentialBlob = pointer, Persist = PersistLocalMachine,
                UserName = Environment.UserName
            };
            if (!CredWrite(ref credential, 0)) throw new InvalidOperationException("API-Key konnte nicht im Windows-Anmeldeinformationsmanager gespeichert werden.");
        }
        finally { Marshal.FreeCoTaskMem(pointer); }
    }

    public static string? Load()
    {
        if (!CredRead(Target, Generic, 0, out var pointer)) return null;
        try
        {
            var credential = Marshal.PtrToStructure<Credential>(pointer);
            return Marshal.PtrToStringUni(credential.CredentialBlob, (int)credential.CredentialBlobSize / 2);
        }
        finally { CredFree(pointer); }
    }

    public static void Delete() => CredDelete(Target, Generic, 0);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags; public uint Type; public string TargetName; public string? Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten; public uint CredentialBlobSize;
        public IntPtr CredentialBlob; public uint Persist; public uint AttributeCount; public IntPtr Attributes;
        public string? TargetAlias; public string UserName;
    }
    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool CredWrite(ref Credential credential, uint flags);
    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode)] private static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll")] private static extern void CredFree(IntPtr credential);
}

public static class StartupService
{
    private const string Name = "Quick Text";
    public static bool IsEnabled
    {
        get => Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")?.GetValue(Name) != null;
        set
        {
            using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
            if (value) key.SetValue(Name, $"\"{Environment.ProcessPath}\" --background");
            else key.DeleteValue(Name, false);
        }
    }
}

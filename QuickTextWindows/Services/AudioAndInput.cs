using System.Diagnostics;
using System.Runtime.InteropServices;
using NAudio.Wave;

namespace QuickTextWindows.Services;

public sealed class AudioRecorder : IDisposable
{
    private WaveInEvent? input;
    private WaveFileWriter? writer;
    private Stopwatch? timer;
    public string? FilePath { get; private set; }
    public TimeSpan Duration => timer?.Elapsed ?? TimeSpan.Zero;
    public bool IsRecording => input != null;

    public void Start()
    {
        FilePath = Path.Combine(Path.GetTempPath(), $"quicktext-{Guid.NewGuid():N}.wav");
        input = new WaveInEvent { WaveFormat = new WaveFormat(16000, 1), BufferMilliseconds = 50 };
        writer = new WaveFileWriter(FilePath, input.WaveFormat);
        input.DataAvailable += (_, e) => writer?.Write(e.Buffer, 0, e.BytesRecorded);
        input.StartRecording();
        timer = Stopwatch.StartNew();
    }

    public string Stop()
    {
        timer?.Stop();
        input?.StopRecording();
        input?.Dispose();
        writer?.Dispose();
        input = null; writer = null;
        return FilePath ?? throw new InvalidOperationException("Keine Aufnahme vorhanden.");
    }

    public void Dispose()
    {
        input?.Dispose(); writer?.Dispose();
        if (FilePath != null) try { File.Delete(FilePath); } catch { }
    }
}

public static class PasteService
{
    public static void Paste(string text, IntPtr target)
    {
        System.Windows.Clipboard.SetText(text);
        if (target == IntPtr.Zero) return;
        SetForegroundWindow(target);
        Thread.Sleep(120);
        keybd_event(0x11, 0, 0, UIntPtr.Zero);
        keybd_event(0x56, 0, 0, UIntPtr.Zero);
        keybd_event(0x56, 0, 2, UIntPtr.Zero);
        keybd_event(0x11, 0, 2, UIntPtr.Zero);
    }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
}

public sealed class GlobalHotkeyService : IDisposable
{
    private const int HookKeyboard = 13, KeyDown = 0x0100, KeyUp = 0x0101, SysDown = 0x0104, SysUp = 0x0105;
    private const int Shift = 0x10, LeftShift = 0xA0, RightShift = 0xA1;
    private const int Control = 0x11, LeftControl = 0xA2, RightControl = 0xA3;
    private const int Alt = 0x12, LeftAlt = 0xA4, RightAlt = 0xA5;
    private const int LeftWin = 0x5B, RightWin = 0x5C, Escape = 0x1B;
    private readonly HookProc callback;
    private IntPtr hook;
    private readonly HashSet<int> pressed = [];
    private WorkflowType? active;
    public event Action<WorkflowType, bool>? Triggered;
    public event Action? Cancelled;

    public GlobalHotkeyService()
    {
        callback = Handle;
        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule!;
        hook = SetWindowsHookEx(HookKeyboard, callback, GetModuleHandle(module.ModuleName), 0);
    }

    private IntPtr Handle(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0)
        {
            var key = Marshal.ReadInt32(data);
            var down = message == (IntPtr)KeyDown || message == (IntPtr)SysDown;
            if (down) pressed.Add(key); else pressed.Remove(key);
            if (down && key == Escape) Cancelled?.Invoke();

            var combo = Resolve();
            if (combo != null && active == null) { active = combo; Triggered?.Invoke(combo.Value, true); }
            else if (active != null && combo != active) { var old = active.Value; active = null; Triggered?.Invoke(old, false); }
        }
        return CallNextHookEx(hook, code, message, data);
    }

    private WorkflowType? Resolve()
    {
        var win = pressed.Contains(LeftWin) || pressed.Contains(RightWin);
        if (!win) return null;
        var shift = IsPressed(Shift, LeftShift, RightShift);
        var ctrl = IsPressed(Control, LeftControl, RightControl);
        var alt = IsPressed(Alt, LeftAlt, RightAlt);
        if (shift && ctrl && !alt) return WorkflowType.LocalTranscription;
        if (shift && !ctrl && !alt) return WorkflowType.Transcription;
        if (ctrl && alt && !shift) return WorkflowType.EmojiText;
        if (ctrl && !shift && !alt) return WorkflowType.TextImprover;
        if (alt && !shift && !ctrl) return WorkflowType.DampfAblassen;
        return null;
    }

    private bool IsPressed(params int[] keys) => keys.Any(pressed.Contains);

    public void Dispose() { if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook); }
    private delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int id, HookProc callback, IntPtr module, uint thread);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string? name);
}

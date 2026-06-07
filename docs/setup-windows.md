# Windows 11 Setup

The Windows app mirrors the macOS preview with a native tray app, the same
online workflows, hold/toggle hotkeys, automatic clipboard paste, secure
credential storage, startup-at-login, and optional local transcription.

## Requirements

- Windows 11 ARM64 or x64
- .NET 8 SDK for building
- An OpenAI API key for online transcription and rewriting
- Optional: `whisper.cpp` for local-only transcription

## Build And Run

Open PowerShell in the repository:

```powershell
.\build-windows.ps1 -Configuration Debug -Run
```

Create self-contained ARM64 and x64 setup builds:

```powershell
.\build-windows.ps1 -Configuration Release
```

The build creates:

- `QuickText-Windows-11-win-arm64\Quick Text Setup.exe`
- `QuickText-Windows-11-win-x64\Quick Text Setup.exe`
- matching ZIP transfer packages for both architectures

On a Windows 11 ARM PC, extract `QuickText-Windows-11-win-arm64.zip` and
double-click **Quick Text Setup.exe**. The setup dialog installs the native
ARM64 app for the current user and can start it immediately.

The adjacent `app` folder is required by the setup and must be copied together
with the setup executable.

## Configure

Open Quick Text from the notification area, choose **Einstellungen**, and save
your OpenAI API key. It is stored in Windows Credential Manager, never in
`settings.json`.

Windows hotkeys use the Windows key in place of the Mac `fn` key:

| Workflow | Windows hotkey |
|---|---|
| Quick Text | Win + Shift |
| Quick Text Lokal | Win + Shift + Ctrl |
| Quick Text+ | Win + Ctrl |
| Quick Text $%&! | Win + Alt |
| Quick Text :) | Win + Ctrl + Alt |

Both **Halten** and **Toggle** behavior are available from settings. Press
Escape to cancel the current recording.

## Optional Local Transcription

The macOS implementation uses WhisperKit/CoreML, which is not available on
Windows. The functionally equivalent Windows path uses `whisper.cpp`.

1. Download a Windows build containing `whisper-cli.exe` that matches the PC
   architecture from
   [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp).
2. Download the multilingual `ggml-small.bin` model.
3. In Quick Text settings, click **Modellordner öffnen**.
4. Place both files directly in that folder.
5. Enable **Sicherer Lokaler Modus**.

Expected path:

```text
%LOCALAPPDATA%\Quick Text\models\whisper.cpp\
  whisper-cli.exe
  ggml-small.bin
```

In secure local mode, audio stays on the PC and rewriting workflows are paused.

## Windows Permissions And Troubleshooting

- Allow microphone access under **Settings > Privacy & security > Microphone**.
- Auto-paste works through the clipboard plus simulated `Ctrl+V`. Applications
  running as administrator cannot be controlled by a non-administrator app.
- If a Windows-key shortcut is reserved by Windows or another tool, close that
  tool before using Quick Text.
- The preview has no updater. Rebuild it from the repository for updates.

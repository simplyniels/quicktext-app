# Repository Guide

## Scope

Quick Text is a native tray/menu-bar speech-to-text app with separate macOS and
Windows implementations:

- `QuickTextMac/`: SwiftUI/AppKit implementation for macOS 14+
- `QuickTextWindows/`: WPF implementation for Windows 11 and .NET 8
- `QuickTextServer/`: Next.js/Vercel family server backed by Supabase

Keep both apps functionally aligned. A workflow, setting, API model, prompt, or
user-facing behavior changed on one platform should normally be changed on the
other platform in the same pull request.

## Product Invariants

- Never commit API keys, recordings, transcripts, or other user data.
- OpenAI keys must stay in the platform credential store.
- Hosted mode must never expose the server's OpenAI key or Supabase service
  role key to any client.
- Online transcription uses `whisper-1`.
- Text improvement and emoji workflows use `gpt-4o-mini`.
- The calmer-message workflow uses `gpt-4o`.
- Completed output is copied to the clipboard and pasted into the previously
  focused application when possible.
- Secure/local mode must not send audio or text to OpenAI.
- Keep German workflow names, subtitles, prompts, and status messages aligned
  across platforms.

## Build And Verify

macOS:

```bash
./build.sh --debug
```

Windows 11 ARM64 and x64 (PowerShell 7 or Windows PowerShell):

```powershell
.\build-windows.ps1 -Configuration Debug
```

The Windows build requires the .NET 8 SDK. Local transcription additionally
requires a matching-architecture `whisper-cli.exe`; the app explains and opens
the expected folder. Windows release folders must contain `Quick Text Setup.exe`
and the adjacent `app/` payload.

## Editing Guidance

- Prefer platform-native APIs and UI conventions.
- Keep platform-specific code inside its platform directory.
- Preserve the preview/no-hosted-backend data flow.
- If implementing hosted or mobile support, follow
  `docs/hosted-mobile-architecture.md` and keep direct-key and local modes
  available as fallbacks.
- Update `README.md` and the relevant setup document when requirements or setup
  steps change.
- Treat build output (`bin/`, `obj/`, `.derivedData-*`, `.app`, publish folders)
  as generated files.

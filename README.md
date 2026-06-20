# Quick Text

Quick Text is an experimental open-source macOS menu-bar, Windows 11 tray, Android floating-dictation, and iOS companion-keyboard app for turning speech into text.

It is intentionally small and unfinished. The goal is to make a real workflow visible and hackable: press a hotkey, speak, get text back, optionally rewrite it, and paste it into the app you were using.

This is a learning and experimentation project, not a polished product.

> Preview status: bring your own OpenAI API key, no hosted backend, no warranty, no support guarantee.

## What It Does

- **Quick Text**: record speech and transcribe it.
- **Quick Text+**: record speech, transcribe it, then turn the rough draft into cleaner writing.
- **Quick Text $%&!**: turn frustrated speech into a calmer message.
- **Quick Text :)**: add fitting emojis to dictated text.

## Important Preview Notes

- Native macOS and Windows 11 implementations plus a Flutter mobile app with
  native Kotlin Android integration and a native Swift iOS keyboard extension.
- Bring your own OpenAI API key.
- No hosted Quick Text backend is included or provided.
- A hosted family-server and mobile-app extension is planned in
  [docs/hosted-mobile-architecture.md](docs/hosted-mobile-architecture.md).
- In online mode, audio and text are sent directly from the app to the OpenAI API.
- Optional local transcription via WhisperKit/CoreML if you install a compatible model locally.
- `./build.sh` creates a locally ad-hoc-signed development app. No notarized release binary is provided.
- Not production ready.
- No warranty and no support guarantee.

You are welcome to use, fork, adapt, and share this project under the license terms.

The intent is not to ship a one-click finished app. The intent is to make a real AI workflow understandable: clone it, build it, read the code, change it, break it, fix it, and suggest improvements. If you only want to download something and never look inside, this preview will probably feel rough. If you want to learn how a small native macOS AI app is put together, you are in the right place.

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/online-mode.png" alt="Quick Text online transcription mode" width="420"></td>
    <td><img src="docs/screenshots/local-mode.png" alt="Quick Text secure local transcription mode" width="420"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/local-model-picker.png" alt="Quick Text local model picker" width="420"></td>
    <td><img src="docs/screenshots/settings-customize.png" alt="Quick Text settings and customization view" width="420"></td>
  </tr>
</table>

## Requirements

### macOS

- macOS 14 or newer
- Xcode 16 or newer (Swift 5.10), with Command Line Tools installed and selected for `xcodebuild`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project
- For online transcription and rewriting: an OpenAI API key with access to:
  - `whisper-1` for transcription
  - `gpt-4o-mini` and optionally `gpt-4o` for rewriting
- For local-only transcription: a WhisperKit CoreML model in:
  `~/Library/Application Support/Quick Text/models/whisperkit/`

The build also pulls one Swift Package dependency automatically:

- [`argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift) (WhisperKit) — used for local on-device transcription.

### Windows 11

- Windows 11 ARM64 or x64
- .NET 8 SDK for building
- Optional local transcription via `whisper.cpp`

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build And Run

```bash
git clone https://github.com/cmagnussen/quicktext-app.git
cd quicktext-app
./build.sh --run
```

For a local install into `/Applications`:

```bash
./build.sh --install --run
```

The generated `.app` is ad-hoc signed for local development only. Do not treat it as a trusted redistributable binary. A public binary release would need Developer ID signing and notarization.

On first launch, either paste your own OpenAI API key for online workflows or install a WhisperKit CoreML model for local transcription. Rewriting workflows still require OpenAI.

For fully local transcription, install a WhisperKit CoreML model and enable **Sicherer Lokaler Modus** in the app.

For a slower, more explicit walkthrough, see [docs/setup.md](docs/setup.md).

### Build And Run On Windows 11

```powershell
.\build-windows.ps1 -Configuration Debug -Run
```

For native ARM64 and x64 setup builds:

```powershell
.\build-windows.ps1 -Configuration Release
```

See [docs/setup-windows.md](docs/setup-windows.md) for installation, Windows
hotkeys, microphone permissions, and optional local transcription.

### Build And Run On Android

```bash
cd QuickTextMobile
flutter run
```

Android 13 or newer is required. The containing app stores the OpenAI API key
in Android Keystore. Its native Accessibility Service shows a floating Quick
Text bubble when a regular text field and the software keyboard are active.
See [docs/setup-android.md](docs/setup-android.md) for setup, privacy behavior,
and device testing.

### Build And Run On iOS

```bash
cd QuickTextMobile
flutter run
```

The iOS containing app records, transcribes, optionally rewrites, and copies the
result. Its native Quick Text keyboard can insert that clipboard result at the
cursor after the user enables the keyboard and Full Access. iOS does not permit
a system-wide floating bubble or microphone access inside third-party keyboard
extensions. See [docs/setup-ios.md](docs/setup-ios.md).

## Permissions

Quick Text asks for:

- **Microphone**: to record your voice.
- **Accessibility**: to paste the result back into the app you were using.

If you do not grant Accessibility permission, you can still copy results manually.

On Windows, microphone access is controlled under **Privacy & security >
Microphone**. Direct paste uses the clipboard plus simulated `Ctrl+V`; no
separate accessibility permission exists.

Full Disk Access is not required. If auto-paste does not work even though transcription succeeds, open **System Settings -> Privacy & Security -> Accessibility**, enable Quick Text there, restart Quick Text, and try again with the cursor focused in a text field. If macOS shows multiple Quick Text entries, remove or disable the old ones and grant the permission to the app you just built or installed.

## Data Flow

The preview has no custom backend.

```text
Online transcription: Your device -> OpenAI Audio Transcriptions API
Text rewriting:       Your device -> OpenAI Chat Completions API
Local transcription:  Your device -> WhisperKit/CoreML or whisper.cpp
```

The app stores your OpenAI API key in macOS Keychain or Windows Credential Manager.

Read [docs/privacy.md](docs/privacy.md) before using the preview with sensitive content.

## Project Structure

```text
QuickTextMac/
  App/          App lifecycle and paste handling
  Features/     Workflows, menu bar UI, settings
  Services/     Recording, OpenAI calls, hotkeys, local storage
  Views/        Shared SwiftUI views
QuickTextWindows/
  Services/     Recording, OpenAI, hotkeys, credentials, local transcription
  App.cs        Tray lifecycle
  MainWindow.cs Main UI, settings, and workflow coordination
QuickTextMobile/
  lib/          Shared Flutter onboarding, settings, and iOS recording UI
  android/      Native Kotlin accessibility overlay, recording, and insertion
  ios/          Native Swift recording bridge and Quick Text keyboard extension
build.sh        Local build script
build-windows.ps1 Windows build, publish, and install script
docs/           Setup, privacy, roadmap, preflight, landing page notes
```

## Local Models

Local transcription is available as an experimental WhisperKit/CoreML path. The app does not bundle a model; choose one in the app, click install, and then switch on **Sicherer Lokaler Modus** from the menu bar or settings.

See [docs/local-models.md](docs/local-models.md).

## Contributing

Contributions are welcome, especially if they make the preview easier to build, understand, or fork.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Support And Roadmap

This preview has no formal support promise. See [SUPPORT.md](SUPPORT.md) for how to ask for help without sharing secrets.

The current direction is documented in [ROADMAP.md](ROADMAP.md). Maintainer-facing release checks live in [docs/open-source-preflight.md](docs/open-source-preflight.md).

## License

Code is released under the MIT License. See [LICENSE](LICENSE).

Project names, logos, and app icons are not automatically granted as trademarks or brand assets. See [TRADEMARKS.md](TRADEMARKS.md).

## Legal / Impressum & Datenschutz

This is an experimental, non-commercial open-source project, provided as-is under the MIT License without warranty or support. Nothing is sold here and no installation or operation is performed on your behalf.

The companion website (quicktext.de) is operated by Blackboat Internet GmbH:

- Impressum: https://www.blackboat.com/impressum
- Datenschutz / Privacy: https://www.blackboat.com/datenschutz

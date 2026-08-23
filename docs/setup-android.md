# Quick Text Setup On Android

## Requirements

- Android 13 or newer
- Flutter 3.44 or newer and an Android SDK for building
- An OpenAI API key with access to `gpt-transcribe`, `gpt-4o-mini`, and `gpt-4o`

## Build And Install

```bash
cd QuickTextMobile
flutter pub get
flutter build apk --debug
```

The debug APK is written to
`QuickTextMobile/build/app/outputs/flutter-apk/app-debug.apk`.

## First Setup

1. Open Quick Text and enter the OpenAI API key. It is encrypted with a key
   held by Android Keystore and is never written to source files.
2. Grant microphone and notification permission. Audio capture starts only
   after the user taps the bubble.
3. Tap **Floating Bubble aktivieren**, select Quick Text under installed
   accessibility apps, and enable the service.
4. Choose **German**, **English**, **French**, or **Auto** as the dictation
   language, then choose the workflow and save.
5. Under **Darstellung**, choose **Auto**, **Hell**, or **Dunkel**. Auto follows
   the Android system appearance.

Open a regular text field in a messaging, mail, browser, or notes app. When the
software keyboard appears, Quick Text places a blue bubble above it. Tap the
bubble, marked with the Quick Text app symbol, to record. The bubble becomes a
recording pill with a live, audio-responsive waveform, timer, and red stop
button. Stopping sends the recording to `gpt-transcribe`; the selected optional
rewrite then uses `gpt-4o-mini` or `gpt-4o`.

Drag the bubble to move it away from app controls such as Send or Attach. Quick
Text remembers the position and keeps a safety distance above the keyboard.
Short accessibility-focus changes are debounced so the bubble stays visually
stable while a text field remains active.

Quick Text copies every successful result to the Android clipboard. It also
tries to paste at the current cursor through the active accessibility input. If
an app uses a custom or protected input control and rejects insertion, the
clipboard remains available as the fallback.

## Accessibility And Privacy

The Accessibility Service is required because a regular Android app cannot
detect focused text fields or insert into other apps. Quick Text uses it only to:

- determine whether a non-password editable field and the software keyboard
  are active;
- show or hide the dictation bubble;
- insert the result into the currently focused field.

It does not show the bubble in password fields and does not collect, store, or
log content from other apps. Recordings are temporary cache files and are
deleted after success or failure. In this preview, recordings and optional
rewrite text go directly from the device to OpenAI; hosted mode remains planned
in `docs/hosted-mobile-architecture.md`.

## Known Platform Limits

- Some apps use custom editors that reject Accessibility paste actions. The
  clipboard fallback covers these cases.
- Android or an OEM battery manager can stop an Accessibility Service. Re-enable
  Quick Text in Accessibility settings if the bubble no longer appears.
- The current preview limits each recording to 60 seconds.
- Secure/password fields are deliberately excluded.

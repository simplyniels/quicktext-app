# Quick Text Setup On iOS

## Requirements

- iOS 15 or newer
- Xcode 16 or newer and Flutter 3.44 or newer for building
- An OpenAI API key with access to `gpt-transcribe`, `gpt-4o-mini`, and `gpt-4o`

## Build And Run

```bash
cd QuickTextMobile
flutter pub get
flutter run
```

For a simulator-only build:

```bash
flutter build ios --simulator
```

The Xcode workspace is `QuickTextMobile/ios/Runner.xcworkspace`. The Runner app
embeds the `QuickTextKeyboard` extension.

To export a development-signed IPA from an existing archive:

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/development-export \
  -exportOptionsPlist ios/ExportOptions-Development.plist \
  -allowProvisioningUpdates
```

App Store export additionally requires an Apple Distribution certificate and
App Store provisioning profiles for both `de.quicktext.mobile` and
`de.quicktext.mobile.keyboard`.

## First Setup

1. Open Quick Text, enter the OpenAI API key, and save. The key is stored in the
   iOS Keychain with this-device-only protection.
2. Grant microphone access.
3. Choose **German**, **English**, **French**, or **Auto** as the dictation
   language, then choose the workflow.
   Under **Darstellung**, choose **Auto**, **Hell**, or **Dunkel**. Auto follows
   the iOS appearance. The keyboard extension always follows iOS directly.
4. Open **Settings → General → Keyboard → Keyboards → Add New Keyboard** and
   select Quick Text.
5. Open Quick Text in that list and enable **Allow Full Access**. This is needed
   only so the keyboard can read the clipboard after an explicit tap.

## Dictation Flow

1. For Apple's built-in dictation, tap the system microphone at the bottom
   right while the Quick Text keyboard is visible. For Quick Text's `gpt-transcribe`
   and rewrite workflows, open Quick Text and tap the purple microphone in the
   containing app.
2. Speak, then tap the red stop button. Recordings stop automatically after
   60 seconds.
3. Quick Text sends the temporary recording to `gpt-transcribe`, optionally runs the
   selected text workflow, and copies the result to the iOS clipboard.
4. Return to the target app, select the Quick Text keyboard with the globe key,
   and tap **Letztes Diktat einfügen**.

The extension inserts the clipboard text at the current cursor by using Apple's
`textDocumentProxy`. It reads the clipboard only when the user taps the insert
button. Temporary audio is deleted after success or failure.

## iOS Platform Limits

iOS third-party keyboard extensions cannot access the microphone, draw outside
their keyboard view, or show a floating overlay above another app. Secure text
fields, phone-pad fields, and apps that explicitly reject custom keyboards use
Apple's system keyboard instead. Therefore the Android bubble interaction
cannot be reproduced exactly on iOS.

Quick Text declares ASCII capability so it is eligible for normal, email, URL,
and other ASCII-compatible text fields. An app can nevertheless reject all
third-party keyboards; Quick Text cannot override that host-app policy.

The current design keeps microphone capture in the containing app and uses the
keyboard only for explicit insertion. This is the closest reliable system-wide
flow available through public iOS APIs.

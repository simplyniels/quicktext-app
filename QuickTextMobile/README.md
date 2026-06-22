# Quick Text Mobile

The Flutter host app for Quick Text on iOS and Android. iOS also includes the
native `QuickTextKeyboard` extension for inserting the latest dictation at the
cursor.

## Languages

The app and iOS keyboard support English and German. The phone language is used
automatically: German is selected for German system locales; every other system
locale falls back to English. This app-language selection is independent from
the dictation-language setting.

## Verify

```bash
flutter analyze
flutter test
flutter build ios --simulator --debug
```

For a TestFlight upload, increment `version` in `pubspec.yaml`, then archive and
export with `ios/ExportOptions-AppStore.plist` using the configured Apple team.

The custom iOS keyboard intentionally relies on iOS's own bottom globe and
microphone controls instead of drawing duplicate controls above them.

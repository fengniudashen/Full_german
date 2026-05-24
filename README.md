# DeutschFlow

DeutschFlow is a cross-platform Flutter app for German dictation practice. It uses drift SQLite storage, just_audio playback, provider state management, file_picker imports, share_plus CSV export, and flutter_audio_waveforms on the timeline annotation screen.

## First-time setup

This workspace contains the full Dart source and pubspec. If native platform runner folders are missing, generate them with Flutter SDK:

```bash
flutter create --platforms=windows,macos,android,ios --project-name deutschflow .
flutter pub get
```

If `flutter create` changes `pubspec.yaml` or `lib/main.dart`, restore the versions in this workspace.

For China mainland networks, use these mirrors before running Flutter commands:

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
```

This workspace is configured to use a local SDK at `.tooling/flutter` when present.

## Run

```bash
flutter run -d windows
flutter run -d macos
flutter run -d android
flutter run -d ios
```

## Build

```bash
flutter build windows --release
flutter build macos --release
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

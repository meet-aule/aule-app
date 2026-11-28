# The platform folders

`android/` and `ios/` come from the Flutter 3.47.7 templates, written with:

```sh
flutter create --no-pub --org com.meetaule --project-name aule --platforms android,ios .
```

That command only writes template files; it fetches no package and builds nothing. What was changed in the templates, and why, is below. To refresh them after a Flutter upgrade, run the same command (it keeps files that exist) and delete `test/widget_test.dart` if it appears.

The first `flutter pub get` also writes `lib/core/l10n/app_localizations*.dart`, which `.gitignore` keeps out of the repository.

## 1. Android

The app has `minSdk` 24 and `targetSdk` 36. Its `compileSdk` is 37 for permission_handler_android. Install `platforms;android-37.0`. Android Gradle Plugin 9.1.1 recognizes that SDK.

`android/app/src/main/AndroidManifest.xml` adds to the template:

| Entry | Why |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE` | The platform and LiveKit. |
| `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` | LiveKit. The microphone is asked for only when the parent steps in. |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT` | Device setup, Android 12 and later. |
| `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, all `maxSdkVersion="30"` | Device setup, Android 7 to 11, where a Bluetooth scan needs location. The setup screen says so before the OS asks. |
| `uses-feature bluetooth_le`, not required | The app installs on phones without BLE; setup then offers the code. |
| `queries` for `https` VIEW and `mailto` SENDTO | url_launcher: the privacy policy and the support address. |
| `android:label="Aule"`, `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules` | Nothing about the family goes to a backup or a device transfer. |

There is no CAMERA permission: the parent's camera is never used. Android needs no permission text in the manifest; the in-app screens explain Bluetooth (and, on Android 7 to 11, location) before the OS asks, and the microphone before step-in.

`android/app/src/main/res/xml/data_extraction_rules.xml` excludes every domain from cloud backup and device transfer (Android 12 and later; `allowBackup="false"` covers older versions).

`android/app/src/debug/AndroidManifest.xml` allows cleartext traffic in debug builds only, to reach `http://10.0.2.2:8091`. Release builds keep the platform default for API 28 and later: no cleartext.

`MainActivity.kt` calls `setRecentsScreenshotEnabled(false)` on Android 13 and later, so the recent-apps screen shows no snapshot of notices, summaries or memories, while screenshots the parent takes on purpose still work. Android 7 to 12 still show a snapshot; `FLAG_SECURE` would hide it but would also block those screenshots, so it is left to the owner.

## 2. iOS

The deployment target is iOS 15.0, and the template uses the UIScene lifecycle. Every plugin in `pubspec.yaml` supports Swift Package Manager, so there is no Podfile (the CocoaPods registry becomes read-only on 2026-12-02). With SwiftPM, permission_handler compiles in only the permissions whose Info.plist keys exist, so no Podfile macros are needed either.

`ios/Runner/Info.plist` adds to the template:

| Key | Value |
|---|---|
| `CFBundleDevelopmentRegion` | `es` |
| `CFBundleLocalizations` | `es`, `en` |
| `NSBluetoothAlwaysUsageDescription` | Bluetooth only to find the Aule device and give it the Wi-Fi. |
| `NSMicrophoneUsageDescription` | The microphone only when the parent chooses to talk in a session. |
| `NSCameraUsageDescription` | "Aule does not use the camera." The WebRTC binary references the camera, and App Store Connect can reject an upload without the key (ITMS-90683); the prompt never shows. |
| `NSLocalNetworkUsageDescription` | The local network only to connect a session's sound. WebRTC may trigger the iOS 14+ local-network prompt when the parent joins; this has to be checked on a real iPhone. |
| `ITSAppUsesNonExemptEncryption` | `false`: it assumes HTTPS and the AES of the Wi-Fi setup count as exempt. The owner confirms it. |

There are no `NSLocation*` or `UIBackgroundModes` keys. If Google sign-in ever ships on iOS (with Apple, gap 7), it needs `GIDClientID`, `GIDServerClientID`, and `CFBundleURLTypes` with the reversed iOS client id.

The localized prompts are in `ios/Runner/es.lproj/InfoPlist.strings` and `ios/Runner/en.lproj/InfoPlist.strings`. `Runner.xcodeproj` lists them as one `InfoPlist.strings` variant group in the Runner target's resources, and adds `es` to the known regions.

The template's `DEVELOPMENT_TEAM` was removed from `Runner.xcodeproj`: each developer picks a signing team in Xcode, and the repository names none.

`AppDelegate.swift` covers each window with a plain paper-coloured view when a scene enters the background, and removes it when the scene comes back, so the app switcher's snapshot shows nothing about a child. It listens for `UIScene.didEnterBackgroundNotification`, so system alerts (which only make the app inactive) do not trigger it.

## 3. App ids

`com.meetaule.aule` on both platforms, as proposed; the owner confirms it. The OAuth clients and native Sign in with Apple (gap 7) depend on it.

## 4. Google OAuth clients

Google sign-in is behind the `AULE_FF_GOOGLE` flag and shows on Android only in v0. Register, in the same Google Cloud project as the web client whose id is `AULE_GOOGLE_SERVER_CLIENT_ID`:

- an Android client with the package name and the SHA-1 of every signing key (debug, upload and Play app signing);
- an iOS client with the bundle id, for later.

When `AULE_GOOGLE_SERVER_CLIENT_ID` is empty, the app asks the platform for it (`GET /v1/auth/google`).

## 5. Builds

The Flutter workflow checks the locked packages, analyzes Dart, runs the tests
and builds an ARM64 Android APK with the synthetic demo family. Download
`aule-family-demo-arm64-debug` from the workflow run artifacts for seven days.
The APK uses debug signing. Store distribution needs a separate signing setup.

Every setting is a `--dart-define`. No default points at production: with no API base the app runs in demo mode.

```sh
# Demo: in-memory fakes, every flag but Google on, and no OS prompt for
# Bluetooth, location or the microphone. No byte leaves the phone.
flutter run
flutter run --dart-define=AULE_DEMO=true

# The platform on a developer's machine (Android emulator; use
# http://127.0.0.1:8091/v1 on the iOS simulator).
flutter run \
  --dart-define=AULE_API_BASE=http://10.0.2.2:8091/v1

# Production, once encryption to the origin is verified (gap 1). Turn a flag on only
# when its server work is live (README, "Server gaps").
flutter build appbundle \
  --dart-define=AULE_API_BASE=https://playground.meetaule.com/session/api/v1 \
  --dart-define=AULE_VERSION=0.1.0 \
  --dart-define=AULE_FF_SESSIONS=false \
  --dart-define=AULE_FF_LIVE=false \
  --dart-define=AULE_FF_DEVICE_LINK=false \
  --dart-define=AULE_FF_BLE_WIFI=false \
  --dart-define=AULE_FF_GOOGLE=false
```

| Define | Meaning | Default |
|---|---|---|
| `AULE_API_BASE` | The platform, ending in `/v1` | empty, which means demo mode |
| `AULE_PLAYGROUND_URL` | Optional HTTPS base of the browser tutor for opening a published activity | derived from an API base ending in `/api/v1`; demo mode uses bundled guides only |
| `AULE_DEMO` | Force demo mode | `false` |
| `AULE_FF_SESSIONS` | Session facts, live detection, and ending a live session after a withdrawal or a deletion (gap 3) | `false` |
| `AULE_FF_LIVE` | Listening in and stepping in (gaps 4a, 4b and 5) | `false` |
| `AULE_FF_DEVICE_LINK` | The devices section and linking (gap 8) | `false` |
| `AULE_FF_BLE_WIFI` | Wi-Fi over Bluetooth (firmware BluFi) | `false` |
| `AULE_FF_GOOGLE` | Google sign-in, Android only | `false` |
| `AULE_GOOGLE_SERVER_CLIENT_ID` | The web OAuth client the platform checks | empty, fetched |
| `AULE_GOOGLE_IOS_CLIENT_ID` | The iOS OAuth client, for later | empty |
| `AULE_PRIVACY_URL` | The privacy policy in Spanish | `https://meetaule.com/legal/privacy` |
| `AULE_PRIVACY_URL_EN` | The privacy policy in English | `https://meetaule.com/en/legal/privacy` |
| `AULE_VERSION` | The version shown in Privacy | `0.1.0` |

To refresh the bundled Apache-2.0 lessons, run
`node tool/sync_teaching_resources.mjs /path/to/aule-sw` from the app root.
The source is `apps/playground/public/teaching-resources.js` in Aule Server.

## 6. Fonts

`assets/fonts/` holds Inter and Source Serif 4 as variable TTFs from google/fonts, both under the SIL Open Font License 1.1 (`OFL-Inter.txt`, `OFL-SourceSerif4.txt`; upstream github.com/rsms/inter and github.com/adobe-fonts/source-serif). The app never loads fonts over the network.

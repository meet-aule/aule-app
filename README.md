# Aule App

<p>
  <a href="https://github.com/meet-aule/aule-hw"><img src="https://img.shields.io/badge/Hardware-aule--hw-1f6feb.svg" alt="Aule hardware"></a>
  <a href="https://github.com/meet-aule/aule-fw"><img src="https://img.shields.io/badge/Firmware-aule--fw-2da44e.svg" alt="Aule firmware"></a>
  <a href="https://github.com/meet-aule/aule-sw"><img src="https://img.shields.io/badge/Server-aule--sw-d97706.svg" alt="Aule server"></a>
  <a href="https://github.com/meet-aule/aule-app"><img src="https://img.shields.io/badge/App-Aule-8250df.svg" alt="Aule app"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="Apache 2.0"></a>
</p>

(English | [Español](README.es.md))

**Aule is the open-source AI tutor.** This repository is the app for the adults around the child: the parent who sets the device up, and anyone the family invites to follow the child's learning.

The device is for the child. The app is for the family. It never becomes a second screen for the child.

## What it does

- **Set up the device.** Connect Aule to Wi-Fi over Bluetooth and link it to the family.
- **Follow progress.** What the child practiced, what they now master and what comes next, in plain language.
- **Join a session.** Listen in, or step in as a human tutor, through the same LiveKit room the device uses.
- **Control privacy.** Consents, what Aule remembers, and deleting the child's data or the whole account, all in one place. Microphone and session settings come after v0.

## Status

v0, in development on the `feat/app-v0` branch. Written from scratch with Flutter for Android and iOS.

- **Works against the platform today** (once it has a public path, gap 1 below): sign-in with an emailed code, the parent's consent before anything about the child, adding and editing children, progress from reviews and skills, notices, and every privacy control (consents, what Aule remembers, deleting a child's data or the whole account).
- **Behind flags until the server or firmware catches up:** session facts and live sessions, listening in and stepping in, linking a device, Wi-Fi over Bluetooth, and Google sign-in (Android only).
- **Runs end to end in demo mode**, with every flag but Google on, invented data, and no Bluetooth, location or microphone prompt.
- **Not built yet.** No binary has been compiled, the analyzer has not run and no test has run. `android/` and `ios/` are the Flutter 3.47.7 templates with the permissions, backup rules and prompts merged in: see [docs/platform.md](docs/platform.md).

## Run it in demo mode

Demo mode needs no server. The app talks to in-memory fakes, and no byte leaves the phone; a thin banner at the top says so.

```sh
flutter pub get                               # also writes the localizations
flutter run                                   # no AULE_API_BASE: demo mode
flutter run --dart-define=AULE_DEMO=true      # the same, explicitly
```

The demo family is invented:

| To try | Use |
|---|---|
| Sign in as the demo guardian, Ana | `ana@example.com`, code `123456` |
| Create a new, empty family | any other address, code `123456`, then a name |
| See the "could not send" state | `error@example.com` |
| Link a device at once | code `K7QM2X` |
| Link a device that confirms after a few seconds | code `W8PZ3R` |
| Join the demo Wi-Fi | password `aule1234` |

Ana has two children, Mati and Lu, with reviews, skills, memories, three notices (one needs attention) and, for Mati, a live session to listen in on. Its time renews when it runs out; once you end it, it stays ended until the app restarts. Device setup finds a pretend "Aule 3F2A" without touching Bluetooth, and stepping in turns on no real microphone. A new demo family starts with no children and no devices.

To run against the platform on your own machine, pass its base URL (Android emulator shown; the iOS simulator uses `http://127.0.0.1:8091/v1`):

```sh
flutter run --dart-define=AULE_API_BASE=http://10.0.2.2:8091/v1
```

Every `--dart-define` and the production build are in [docs/platform.md](docs/platform.md).

```sh
flutter test                # unit and widget tests
dart format lib test        # the only check run while writing v0
```

## How the code is laid out

```
android/, ios/                the platform projects (docs/platform.md)
lib/main.dart, lib/app.dart   start-up, providers, router, theme
lib/core/                     config, API (HTTP and in-memory fake), auth, storage,
                              router, theme tokens, l10n (es and en), shared widgets
lib/features/auth/            sign-in with an emailed code (Google behind a flag)
lib/features/consent/         the parent's consent, before anything about the child
lib/features/children/        adding and editing children
lib/features/progress/        reviews, skills, sessions and notices
lib/features/privacy/         consents, memories, deleting data and the account
lib/features/device/          device setup: Wi-Fi over Bluetooth, linking
lib/features/live/            joining a live session through LiveKit
```

Every word the family reads comes from `lib/core/l10n/app_es.arb` and `app_en.arb`, in Peruvian Spanish and English. Texts the server writes (summaries, notices, memories) are shown as they come.

## Privacy by design

- Nothing about a child is asked before the parent's consent, and the consent boxes start unticked. The consent screen says what is always kept (the profile, each session's details and summary, progress and notices) and what the parent chooses (memories, written conversations); audio and video are never kept. Every answer, yes or no, is recorded with the version of the words the parent read (`app-2026-11-v2`), and a test fails if those words change without a new version.
- If voice consent cannot be recorded, the child just created is deleted again. If that delete fails too, the app says the profile exists without permission and offers to delete it or try again. A create whose answer was lost is looked for before it is tried again, so a retry never makes a second child.
- Withdrawing voice, or deleting a child or the account, ends a session going on now when the app can see it (`sessionList`), and otherwise says it may go on until it ends (gaps 5 and 6b).
- The guardian's token lives only in the Keychain or the Android cipher store. Nothing about a child is written to disk, and the child's fields ask the keyboard not to learn their words. The manifest turns backups and device transfers off, and release builds allow no cleartext traffic. The app switcher shows no snapshot of the app (iOS, and Android 13 and later).
- No analytics, crash-reporting, ads or Firebase SDK. Release builds log nothing, uncaught errors included. In debug builds the app's own log carries only event names, routes and statuses, and LiveKit logs on its own.
- Joining a live session is built so an adult is never hidden. The app shows the disclosure before every join, however the screen is reached; it joins with a listen-only token and refuses a hidden, data, camera or talking one; it turns the microphone on only after the platform grants it; and it leaves the room when it goes to the background. Telling the child, out loud and on their screen, is the tutor's and the device's part (gap 4b), so `liveJoin` stays off until it ships.
- Email notices carry the notice's full text, and turning them off also stops the attention ones; the app says so before it turns them off (gap 10).

## Server gaps

The app is ready for these. Until each one ships, its flag stays off outside demo mode.

| # | Gap | What the app does meanwhile |
|---|---|---|
| 1 | **No public API.** The platform listens only on its own machine; the web's path is cookie-based. A bearer-only pass-through under `playground.meetaule.com/session/api/v1` is the smallest change. | Demo mode, or a local platform. |
| 2 | **No token renewal.** Sessions last a fixed 30 days. | The parent signs in again with a new code. |
| 3 | **No list of a child's sessions** (`GET /v1/children/{id}/sessions`). | The session list is built from reviews; no live session is found. Flag `sessionList`. |
| 4a | **Guardians cannot join a live session**: no join and mode routes, and the room holds two. | Flag `liveJoin`. |
| 4b | **The child is not told.** The tutor must say, in fixed words and at once, when an adult joins, steps in, hands back, leaves or ends the session, and resume when an adult who was talking disconnects. The web session page, and the device's screen and light once device sessions can be joined, must show "your family is listening" for as long as an adult is in the room. The platform must refuse a join until both exist. | Flag `liveJoin` stays off. The app's part is done: the disclosure, a listen-only join, the microphone only after the grant, and asking for listen mode when the adult hands back or leaves. |
| 5 | **Ending a session does not stop it at once.** | Flag `liveJoin`. After a withdrawal or a deletion, the app says the session may take a few minutes to stop. |
| 6a | **Consent is not created with the child.** | The app creates the child, records consent, and deletes the child if voice cannot be recorded; if that fails, it says the profile exists without permission and offers to delete it. A lost answer is looked for in `me` before a retry. Left: if the parent walks away after a lost answer that `me` could not confirm, the child stays without consent, visible in Family and Privacy, where it can be deleted. Taking the consents in the create call closes this. |
| 6b | **Withdrawing voice, or deleting a child or the account, does not end a running session.** | With `sessionList` on, the app reads the sessions fresh, ends the live ones, and says when it could not. Without it, the sheet says a session going on now may continue. Proposed: the platform ends the child's sessions and deletes their rooms when voice is withdrawn and when a child or a family is deleted. |
| 6c, 6d | No consent history; policy acceptance at sign-up is not recorded. | Not in v0. Nor is asking a family again after the consent wording changes (a new `kConsentPolicyVersion`); that is app work for v1. |
| 7 | **No native Sign in with Apple.** | iOS offers only the emailed code. |
| 8 | **Devices cannot reach activation** through the OTA edge. | Flag `deviceLink`. |
| 9 | Optional: a claim's status; paging for notices, reviews and memories; inviting a second guardian; a data export, and reading the kept conversations. | Not in v0. The app shows the latest 100 memories and says so when there may be more. |
| 10 | **One email switch for every notice.** Turning it off also stops the attention notices, and every email carries the notice's full text. | The app says so in the help and asks before turning emails off. Proposed: separate switches for summaries and attention notices, attention on by default; attention emails that say where to look rather than what happened; next steps for urgent cases. |

The firmware must also turn BluFi on for aule-v0.2, stop logging the Wi-Fi password, bounds-check the SSID and password, and advertise a name per unit before `bleWifi` goes on. Once device sessions can be joined, it must also show on the e-ink and with its light that an adult is listening or talking (gap 4b).

**Before the app ships:** the edge's origins should be HTTPS (Cloudflare Origin CA) or a Tunnel, so the bearer token never crosses the internet in clear text between the edge and the server.

## How the pieces fit

```
aule-hw   the device: board, e-ink, audio, enclosure
aule-fw   firmware: xiaozhi-esp32 + a LiveKit (WebRTC) transport
aule-sw   central server: voice tutor, devices, family API
aule-app  the family app                                        (this repository)
```

## License

Apache License 2.0. See [LICENSE](LICENSE). The bundled fonts, Inter and Source Serif 4, are under the SIL Open Font License 1.1 (`assets/fonts/`).

---

Made in Lima, Peru by [Aule](https://meetaule.com) · admin@meetaule.com

# AGENTS.md

Personal Android app (Flutter, `app/`) for one college student: ERP attendance,
GATE 2028 prep from PW, gym/diet/weight log, focus timer, scroll control,
phone usage summary, reminders, and an AI assistant (the orb). Working name
"Focus"; a better name is still open.

## Layout

- `app/lib/main.dart` - shell. Bottom nav has **5 tabs**: Today (overview),
  GATE, Body (Gym | Diet | Weight), Focus (Timer | Scroll | Usage), Classes
  (attendance). Plus the assistant orb. Settings opens from the gear in every
  page header. Don't add nav tabs; put new screens behind a `SubTabs` split or
  in Settings.
- First launch runs `OnboardingScreen` (ERP connect → BMI goal → floating
  bubble). ERP credentials are entered by the user and stored in secure
  storage — never baked into the build.
- `app/lib/ui/` - design system. `tokens.dart` holds colors (`Dissolve`), one
  hue per section (`Hue`), the type scale (`Typo`) and shared motion timings
  (`Motion`). `kit.dart` holds `FocusPage`, `Panel`, `Ring`, `Bar`,
  `SectionLabel`, `SubTabs`, `Rise`.
- `app/lib/features/<name>/` - one folder per feature.
- `app/lib/core/` - storage (`Store`, shared prefs), secrets, notifications,
  background sync, `updater.dart` (in-app updates).
- `app/android/.../kotlin/com/preetam/focus/` - `MainActivity` (method channels
  `focus/scroll`, `focus/app`, `focus/tts`), `ScrollService`, `AssistantBubble`
  (overlay), `PhononSpeaker` / `PhononTTS` (on-device TTS), `Usage` (Digital
  Wellbeing-style screen time).

## UI rules (from user feedback)

- Every screen is a `FocusPage` with its section `hue`. Use the hue for
  subtitle, rings, bars, glows; green/amber/red (`scoreColor`) only for status.
- Text uses `Typo` styles: `title` (page), `display`/`metric` (numbers),
  `heading` (row titles), `body`, `caption`, `label` (section caps). No
  ad-hoc font sizes or hairline weights (w100-w300) for numbers.
- Progress tracks use `Dissolve.track`, not `raised` (too low contrast).
  Rings clamp to available width; never hard-size beyond ~300.
- Motion uses `Motion.fast` / `base` / `slow` / `stagger` and `Motion.curve`
  so every screen feels even. Keep motion purposeful. No decorative animation
  in Settings. Hidden tabs are wrapped in `TickerMode(enabled: false)`.
- Attendance tab shows overall + subjects below 75%; full list is behind
  Details. Gym is intentionally just a workout + rest timer and a log.
- Assistant: typed replies stay silent; mic mode speaks back (Phonon when
  downloaded, else system TTS) and the reply text rolls out with the voice.

## Data

All data is on-device (`Store` / shared prefs); there is no Supabase or
backend. Attendance comes from the college ERP (`attendance_sync.dart`) and is
overwritten on every sync. Manual edits from the phone go through the assistant
tools `edit_subject` / `mark_lecture` (`features/assistant/tools.dart`).

## Secrets

`.env` at repo root (git-ignored, template in `.env.example`) is baked in with
`--dart-define-from-file=../.env`: `DEEPSEEK_API_KEY` and `GITHUB_TOKEN`
(fine-grained, read-only Contents on `kookoocoder/focus`; the repo is private
and the updater needs it to read releases). ERP ID/password are **not** in
`.env` — users enter them in onboarding or Settings → College ERP.

## Voice (Phonon)

On-device TTS from [gradium-ai/xn-ptts](https://github.com/gradium-ai/xn-ptts)
(Phonon 31m, Apache 2.0). Native library lives at
`android/app/src/main/jniLibs/arm64-v8a/libptts_ffi.so` (rebuild with
`ANDROID_NDK_HOME=… ./android/build.sh` in a checkout of xn-ptts). The ~64 MB
model downloads on first request from Hugging Face into app support storage
(Settings → Voice). Until then, replies fall back to system TTS.

## Versions and in-app updates

- Build number = `git rev-list --count HEAD`; versionName = `1.0.<build>`.
  Android's `versionCode` is that build number, so the OS and adb know exactly
  which build is installed:
  `adb shell dumpsys package com.preetam.focus | grep version`
- Channels: `dev` (GitHub prerelease `dev-<build>`) and `stable` (release
  `stable-<build>`). Dev installs also take newer stable builds. Channel and
  commit are shown in Settings > App.
- Ship: commit, then `cd app && tool/release.sh dev "notes"` (or `stable`).
  Small UI/feature tweaks go to `dev`; `stable` only when the user asks. Write
  notes for the user (what changed for them), they show in the update dialog.
- On launch the app checks GitHub, shows changes, size and download progress,
  then hands the APK to the system installer. First time, Android asks to allow
  "Install unknown apps" for Focus.
- Updates only install over a build signed with the same key. Release builds
  currently use the debug keystore of the Mac that builds them; build releases
  from that machine only.

## Build / check

```
cd app
flutter analyze
flutter build apk --debug --dart-define-from-file=../.env
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Known device notes

- Scroll control needs the accessibility service. Its label is "Focus". On
  Android 11 OEM skins it's under "Downloaded apps"/"Installed services"; the
  in-app "Open settings" button deep-links and highlights it where supported.
- Floating assistant needs "Display over other apps". Usage summary needs
  "Usage access" (same source as Digital Wellbeing).

## Open items

- Better app name.
- Desktop/web way to bulk-edit academics data (today only ERP sync + assistant).

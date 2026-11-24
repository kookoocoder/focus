# AGENTS.md

Personal Android app (Flutter, `app/`) for one college student: ERP attendance,
GATE 2028 prep from PW, gym/diet log, focus timer, scroll control, reminders, and
an AI assistant (the orb). Working name "Focus"; a better name is still open.

## Layout

- `app/lib/main.dart` - shell. Bottom nav has **4 tabs only**: Classes
  (attendance), GATE, Body (Gym | Diet), Focus (Timer | Scroll), plus the
  assistant orb. Settings opens from the gear in every page header. Don't add
  nav tabs; put new screens behind a `SubTabs` split or in Settings.
- `app/lib/ui/` - design system. `tokens.dart` holds colors (`Dissolve`), one
  hue per section (`Hue`) and the type scale (`Typo`). `kit.dart` holds
  `FocusPage`, `Panel`, `Ring`, `Bar`, `SectionLabel`, `SubTabs`.
- `app/lib/features/<name>/` - one folder per feature.
- `app/lib/core/` - storage (`Store`, shared prefs), secrets, notifications,
  background sync, `updater.dart` (in-app updates).
- `app/android/.../kotlin/com/preetam/focus/` - `MainActivity` (method channels
  `focus/scroll`, `focus/app`), `ScrollService` (accessibility service).

## UI rules (from user feedback)

- Every screen is a `FocusPage` with its section `hue`. Use the hue for
  subtitle, rings, bars, glows; green/amber/red (`scoreColor`) only for status.
- Text uses `Typo` styles: `title` (page), `display`/`metric` (numbers),
  `heading` (row titles), `body`, `caption`, `label` (section caps). No
  ad-hoc font sizes or hairline weights (w100-w300) for numbers.
- Progress tracks use `Dissolve.track`, not `raised` (too low contrast).
  Rings clamp to available width; never hard-size beyond ~300.
- Keep motion purposeful. No decorative animation in Settings. Hidden tabs are
  wrapped in `TickerMode(enabled: false)`; keep it that way, the user's phone is
  slow and animations in hidden tabs made the orb miss taps.
- Gym is intentionally just a workout + rest timer and a log. Keep it simple.

## Data

All data is on-device (`Store` / shared prefs); there is no Supabase or
backend. Attendance comes from the college ERP (`attendance_sync.dart`) and is
overwritten on every sync. Manual edits from the phone go through the assistant
tools `edit_subject` / `mark_lecture` (`features/assistant/tools.dart`).

## Secrets

`.env` at repo root (git-ignored, template in `.env.example`) is baked in with
`--dart-define-from-file=../.env`: `ERP_*`, `DEEPSEEK_API_KEY`, and
`GITHUB_TOKEN` (fine-grained, read-only Contents on `kookoocoder/focus`; the
repo is private and the updater needs it to read releases).

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

## Open items

- Better app name.
- Desktop/web way to bulk-edit academics data (today only ERP sync + assistant).

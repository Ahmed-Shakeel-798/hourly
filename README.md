# Hourly

A minimalist Android app that tracks your screen time, nudges you once an hour
to jot down what you're doing, and gives you a clean end-of-day report.

Everything stays **100% on your device** — no account, no servers, no analytics.
The release build doesn't even request the internet permission.

## Features

- **Per-app screen time** — reads Android's own usage stats (the same data behind
  Digital Wellbeing) and shows a daily total plus a per-app breakdown.
- **Hourly check-ins** — once an hour a notification asks "What are you doing?".
  Reply **inline, right from the notification** — no need to open the app.
- **Daily report** — a 9 PM reminder plus a report screen with your screen-time
  breakdown and an activity timeline, browsable day by day.
- **Local-only storage** — all check-ins live in an on-device SQLite database.

## How it works

| Concern | Implementation |
|---|---|
| Screen time | `usage_stats` → Android `UsageStatsManager` (needs the "Usage access" permission) |
| Notifications | `flutter_local_notifications` (on-device `AlarmManager`, no push service) |
| Storage | `sqflite` (local SQLite, app-private) |

## Getting started

See [SETUP.md](SETUP.md) for the full toolchain + Android setup. In short:

```bash
flutter pub get
flutter run
```

In the app: tap **Grant access** (Usage access), then **Enable hourly check-ins**.

> **Android only.** iOS does not expose screen-time data to third-party apps.

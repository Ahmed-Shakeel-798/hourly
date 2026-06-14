# Mobile Monitor — setup

A minimalist Android app that tracks per-app screen time, asks "what are you
doing?" once an hour (with an inline reply in the notification), and shows a
daily report. All data stays on-device in SQLite.

> **Android only.** Screen-time data comes from Android's `UsageStatsManager`.
> iOS does not expose this to third-party apps, so it is not supported.

---

## 0. Prerequisites (none are installed yet)

You need: **Flutter SDK**, **Android SDK**, and a **JDK** (bundled with Android
Studio). Easiest path:

1. Install **Android Studio**: https://developer.android.com/studio
   (includes the Android SDK + JDK). Open it once and let it finish setup.
2. Install **Flutter**: https://docs.flutter.dev/get-started/install/windows
   - Unzip to e.g. `C:\dev\flutter`, then add `C:\dev\flutter\bin` to your PATH.
3. Verify:
   ```powershell
   flutter --version
   flutter doctor
   ```
   Resolve anything `flutter doctor` flags (accept Android licenses with
   `flutter doctor --android-licenses`).

### ⚠️ Move the project off OneDrive

OneDrive sync corrupts Gradle/Flutter builds (file locks, partial syncs).
Copy this folder somewhere local first, e.g.:
```powershell
Copy-Item "C:\Users\ahmed\OneDrive\Documents\Software Engineering\MobileMonitor" "C:\dev\mobile_monitor" -Recurse
cd C:\dev\mobile_monitor
```

---

## 1. Generate the Android platform folder

This project ships the Dart source + `pubspec.yaml`. Generate the native
`android/` scaffolding (this won't touch the files in `lib/`):

```powershell
flutter create . --platforms=android --project-name mobile_monitor
flutter pub get
```

> If `flutter create` overwrites `lib/main.dart` or `pubspec.yaml`, re-copy them
> from this repo (they are the versions you want).

---

## 2. Apply the native edits

### a) `android/app/src/main/AndroidManifest.xml`

Add `xmlns:tools` to the `<manifest>` tag, then paste these permissions just
**above** `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />
    ...
```

Inside `<application>` (so check-in replies + scheduled reports survive reboot),
add:

```xml
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
```

### b) `android/app/build.gradle`

`flutter_local_notifications` needs core-library desugaring. Inside the
`android { ... }` block:

```gradle
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    defaultConfig {
        // ...
        minSdkVersion 21   // required by usage_stats + notifications
    }
```

And add the desugaring dependency (at file scope, after `android { }`):

```gradle
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

---

## 3. Run it

Plug in an Android phone (USB debugging on) or start an emulator, then:

```powershell
flutter devices
flutter run
```

In the app:
1. Tap **Grant access** → toggle **Mobile Monitor** on in the Usage-access list,
   then return to the app. Screen time will populate.
2. Tap **Enable hourly check-ins** to start the every-hour notification and the
   9 PM daily-report reminder.
3. When a check-in fires, type straight into the notification's reply field — it
   saves to your timeline without opening the app.

To test the reply flow immediately without waiting an hour, you can temporarily
call `NotificationService.instance.sendTestCheckin()` (e.g. from a button).

---

## Notes & limits

- **Hourly timing** uses Android's inexact alarms (battery-friendly); the OS may
  shift fires by a few minutes, and Doze can delay them when the phone is idle.
- **Per-app names** are derived from package names (`com.instagram.android` →
  "Instagram"). Add the `installed_apps` package later if you want exact labels
  and icons.
- **All data is local.** Uninstalling the app deletes it.

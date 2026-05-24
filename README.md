# SleepKeeper

SleepKeeper is a small macOS menu bar app for keeping a Mac awake.

It has two separate modes:

- `Keep Awake`: prevents idle system sleep so background work can keep running after the display turns off.
- `Keep Display On`: prevents the display from sleeping. This also enables `Keep Awake`.

The app uses macOS power assertions through IOKit. It does not simulate mouse or keyboard input.

## Requirements

- macOS 14 or later
- Xcode command line tools or Xcode
- Swift 5.9 or later

## Run Locally

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --install
./script/build_and_run.sh --logs
```

`--install` copies the app to:

```text
/Applications/SleepKeeper.app
```

It also enables a user LaunchAgent so SleepKeeper can open when you log in:

```text
~/Library/LaunchAgents/com.local.SleepKeeper.login.plist
```

## Menu Bar Status

SleepKeeper shows a menu bar item:

- `SK Sleep`: SleepKeeper is off.
- `SK Awake`: system sleep is blocked, but the display may turn off.
- `SK Lit`: system sleep and display sleep are both blocked.

Shortcuts:

- `Command + Shift + K`: toggle `Keep Awake`
- `Command + Shift + D`: toggle `Keep Display On`

## Build And Test

```bash
swift test
```

To inspect active macOS power assertions:

```bash
pmset -g assertions
```

When `Keep Awake` is enabled, you should see a SleepKeeper `NoIdleSleepAssertion`.
When `Keep Display On` is enabled, you should also see a display sleep prevention assertion.

## Package For Distribution

Create a DMG:

```bash
./script/package_dmg.sh
```

The output is:

```text
dist/SleepKeeper-1.0.0.dmg
```

The DMG contains `SleepKeeper.app` and an `Applications` shortcut. Users can drag the app into Applications.

## Signing Note

The current package script uses ad-hoc signing:

```bash
codesign --force --deep --sign - SleepKeeper.app
```

This is enough for local validation, but it is not Apple Developer ID signing or notarization. On another Mac, users may see an unidentified developer warning.

For smoother public distribution, sign with an Apple Developer ID certificate and notarize the DMG.

## Git Notes

Recommended files to commit:

```text
Package.swift
README.md
Resources/
Sources/
Tests/
script/
.codex/
.gitignore
```

Generated build artifacts are ignored:

```text
.build/
dist/
```

## Limits

SleepKeeper can prevent idle sleep and display sleep while macOS allows it. It cannot reliably keep a MacBook running after the lid is closed, during shutdown/restart, during system updates, or when macOS forces sleep because of low battery or thermal protection.

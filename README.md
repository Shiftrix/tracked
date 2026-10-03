# Tracked

An hour tracker for everything you do in your life — editing videos, gaming,
gym, reading, coding. Track it all here.

## What it is

A local-first time tracker. You press **Start** on an activity, press **Stop**
when done, and every session is logged to an on-device SQLite database.

No cloud. No accounts. No data leaving your device.

## Features

- **One-tap timers** for every activity
- **Live ticking clock** while a session is running
- **Persistent notification** so you always know what's running
- **Custom activities** — name, colour, and icon for each one
- **Monthly heatmap** per activity, shaded by hours logged per day
- **Year view** — twelve mini-months at a glance
- **Today + all-time totals** under the clock
- **Session history** with dates and durations
- **Survives reboots, app kills, and screen locks** — the timer is
  timestamp-based, not tick-based, so nothing is ever lost
- **Dark mode** by default, Material 3, JetBrains Mono throughout
- **Runs on Android and Linux** (from a single codebase)

## Install

### Android

Grab the latest `.apk` from the
[Releases page](../../releases) and open it on your phone.
You'll need to allow installs from unknown sources the first time.

### Linux

Not distributed as a package yet. Build from source:

```bash
flutter build linux --release
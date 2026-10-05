# Tracked

An hour tracker for everything you do in your life — editing videos, gaming,
gym, reading, coding. Track it all here.

## What it is

A local-first time tracker with a gamified XP system. You press **Start** on
an activity, press **Stop** when done, and every session is logged to an
on-device SQLite database.

No cloud. No accounts. No data leaving your device.

## Features

### Tracking
- **One-tap timers** for every activity
- **Live ticking clock** while a session is running
- **Persistent notification** so you always know what's running
- **Today + all-time totals** under the clock
- **Survives reboots, app kills, and screen locks** — the timer is
  timestamp-based, not tick-based, so nothing is ever lost

### Gamification
- **XP for every minute tracked** — 1 XP/min baseline, with per-activity
  multipliers from 0.5× to 3×
- **Minecraft-style XP bar** on the profile with a level badge
- **XP toast** pops up when you stop a session, flame icon on the first
  session of the day
- **Streak counter** with a Duolingo-style flame (lit when you've tracked
  today, greyed out when you haven't)
- **Total time tracked** and **best-ever streak** on the profile

### Customisation
- **Custom activities** — pick a name, colour, and icon for each one
- **XP multiplier per activity** — reward the things you want to do more of
- Full **rename, edit, and delete** on activities and sessions

### Visualisation
- **Monthly heatmap** per activity, days coloured by the activity
- **Tap any day** to see time logged and XP earned
- **Year view** — stacked monthly heatmaps with arrows to change year
- **All-years view** from the profile, aggregating every activity

### Platforms
- **Android** (primary)
- **Linux** (desktop)
- **Dark mode** by default, Material 3, JetBrains Mono throughout

## Install

### Android

Grab the latest `.apk` from the
[Releases page](../../releases) and open it on your phone.
You'll need to allow installs from unknown sources the first time.

### Linux

Not distributed as a package yet. Build from source:

```bash
git clone https://github.com/Shiftrix/life_tracker.git
cd life_tracker
flutter pub get
flutter build linux --release
# Life Tracker

A hour tracker for all things you do in your life, be it editing youtube videos, gaming, drawing, Track everything here! 

What it is: A local-first, Android-only time tracker. You press Start on an activity (Gym, Gaming, Editing, Music, etc.), press Stop when done, and every session is logged to an on-device SQLite database. No cloud, no accounts, no data leaving the phone.

Features built so far:

    Activity list screen — every activity with its all-time total hours.

    Detail screen per activity with:

        Live ticking clock (HH:MM:SS) while a session runs

        Today's total + all-time total under the clock

        Start/Stop button

        Monthly heatmap (current month, shading by hours logged per day)

        Recent sessions list (dates, durations, seconds shown for sub-minute sessions)

        Year-view button (top right) → 12 stacked mini-months, each day a colored dot

    Dark mode, Material 3, indigo accent

    Tap any heatmap day → snackbar with that day's exact time

Status: Core loop is complete and stable. Everything persists, everything recovers, everything is fast.
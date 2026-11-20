# Install LirikTouchBar on your Mac

LirikTouchBar shows time-synced lyrics from Spotify on your MacBook Pro Touch
Bar. It runs in the menu bar and needs no Spotify account or API key.

> This is an unofficial, ad-hoc signed app. It is not on the App Store and is
> not affiliated with Spotify. See the notes at the end before installing.

## What you need

- **A Mac with a Touch Bar.** This includes Intel MacBook Pro models from
  2016–2019 and the 13-inch M1/M2 MacBook Pro (2020–2022). MacBook Air, 14"/16"
  MacBook Pro, and other Macs have no Touch Bar — you can still use the
  floating lyric panel and menu bar tooltip.
- **macOS 13 (Ventura) or later.** The app is universal, so it runs natively on
  both Apple Silicon and Intel Macs.
- **Spotify desktop app** installed (the web player is not supported).
- An internet connection the first time a song's lyrics are fetched. After
  that, lyrics are cached locally.

## Step 1 — Download the app

Go to the [Releases page](https://github.com/handiputraaa/LirikTouchBar/releases)
and download `LirikTouchBar-vX.Y.Z.zip`.

## Step 2 — Install it

1. Double-click the zip to expand it.
2. Drag **LirikTouchBar.app** into your **Applications** folder.
3. Eject/delete the downloaded zip if you like.

## Step 3 — Open it for the first time

Because the app is ad-hoc signed rather than notarized, macOS may warn you.

1. Open **Applications**, find **LirikTouchBar**.
2. **Right-click it → Open**, then confirm **Open** in the dialog.
3. If macOS still refuses, open Terminal and run:

   ```bash
   xattr -cr /Applications/LirikTouchBar.app
   ```

   Then double-click the app again.

There is no Dock icon. Look for a small **♪** icon in the top menu bar — that
means the app is running.

## Step 4 — Allow Spotify access

1. Start playing a song in the Spotify desktop app.
2. LirikTouchBar will ask for permission to control Spotify. Click **OK**.
3. If you accidentally clicked **Don't Allow**, go to
   **System Settings → Privacy & Security → Automation**, expand
   **LirikTouchBar**, and enable the checkbox next to **Spotify**.

A few seconds later, lyrics should appear on your Touch Bar. If they don't,
check that Spotify is actually playing a song (not paused on a blank player).

## Step 5 — Set up the Touch Bar

1. Go to **System Settings → Keyboard → Touch Bar Settings**.
2. Make sure **Show Control Strip** is enabled.
3. You should see a **♪** button in the Control Strip at the right of the
   Touch Bar. Tap it to show or hide the lyric bar.
4. When shown, the current lyric sits on the **left**, next to the close (X)
   button, and **previous / play-pause / next** buttons sit on the **right**.

If the ♪ button doesn't appear, toggle **Show Control Strip** off and on again,
then restart LirikTouchBar from the ♪ menu bar icon → **Quit Lirik**, and reopen
it.

## Step 6 — Preferences (optional)

Click the **♪ menu bar icon → Preferences…**:

- **Refresh interval** — how often the app asks Spotify for the playback
  position. Lower is more responsive but uses more CPU. Default: 0.5s.
- **Font size / visible lines** — controls the floating Lyric Panel.
- **Text when no lyrics are found** — the placeholder shown for songs without
  synced lyrics.
- **Show menu bar icon** — lets you hide the ♪ icon.
- **Launch at login** — start LirikTouchBar automatically.

The ♪ menu also has **Show Lyrics Panel**, **Show/Hide Touch Bar Lyrics**,
**Play/Pause**, **Refresh Lyrics**, and **Quit**.

## Keyboard shortcut

Press **⌥⌘L** (Option + Command + L) to bring the floating Lyric Panel to the
front. This is optional — lyrics are already on the system Touch Bar.

## Troubleshooting

| Problem | What to do |
|---|---|
| No ♪ icon in the menu bar | The app isn't running. Open it again from Applications. |
| "Cannot reach Spotify" | Check Automation permission (Step 4) and that Spotify desktop is running. |
| "No synced lyrics found" | Lyrics come from the community LRCLIB database; coverage varies. Try **Refresh Lyrics** later. |
| Touch Bar shows function keys | Tap the ♪ Control Strip button, or check `~/Library/Logs/LirikTouchBar.log` for "System Touch Bar presented". |
| Permission prompt returned after an update | Rebuilds change the ad-hoc signature; re-approve in Automation settings. |
| App was blocked by Gatekeeper | Run `xattr -cr /Applications/LirikTouchBar.app` and reopen. |

Diagnostics are written to:

```
~/Library/Logs/LirikTouchBar.log
```

## Uninstall

1. ♪ menu bar icon → **Quit Lirik**.
2. Move **LirikTouchBar.app** from Applications to the Trash.
3. Optional — remove cached data and logs:

   ```bash
   rm -rf ~/Library/Application\ Support/LirikTouchBar \
          ~/Library/Logs/LirikTouchBar.log
   ```

## Before you install: two caveats

- **Private APIs:** keeping lyrics on the Touch Bar while other apps are
  focused requires undocumented Apple APIs. A future macOS update may break
  the system bar. The floating Lyric Panel and menu bar tooltip will keep
  working.
- **Lyrics source:** lyrics are fetched from LRCLIB, a community database.
  Copyright belongs to the respective rights holders. Use it for personal,
  non-commercial purposes.

# LirikTouchBar

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A small macOS menu-bar app that mirrors time-synced lyrics from the Spotify
desktop app onto your MacBook Pro Touch Bar.

> **Unofficial project.** Not affiliated with, endorsed by, or connected to
> Spotify AB. "Spotify" is a trademark of Spotify AB. Lyrics are provided by
> the community-run [LRCLIB](https://lrclib.net/) service.

## Features

- Reads the current track and playback position directly from the local
  Spotify desktop app — **no Spotify API keys or developer account required**.
- Fetches time-synced LRC lyrics from LRCLIB and caches them locally.
- Interpolates playback position between polls, so the highlighted line
  changes within ~0.15 seconds.
- Shows lyrics in the menu bar, in a floating Lyric Panel, and on the Touch
  Bar (current line, upcoming lines, progress bar, and play/pause).
- Global hotkey `⌥⌘L` brings the Lyric Panel forward.
- Preferences for refresh interval, font size, visible lines, launch at login.

## About the Touch Bar

Apple's public `NSTouchBar` API only draws an app's Touch Bar while **that app
is frontmost**. A background utility cannot paint the Touch Bar over other
apps without private APIs, so this project deliberately uses only public APIs.

In practice:

- The **menu bar** always shows the current lyric, in any app.
- The **Lyric Panel** owns the Touch Bar while it is focused. Press `⌥⌘L`.
- If you **minimize** the Lyric Panel, the app falls back to an
  application-level Touch Bar so lyrics keep showing. Bring the panel back
  with `⌥⌘L` or the menu bar item.
- When you switch to another app, macOS shows that app's Touch Bar.

Apps that paint the Touch Bar globally rely on private APIs and tend to break
after macOS updates; that is intentionally avoided here.

## Install

### From a release

1. Download `LirikTouchBar-vX.Y.Z.zip` from the
   [Releases](https://github.com/yourname/LirikTouchBar/releases) page.
2. Unzip and drag `LirikTouchBar.app` into `/Applications`.
3. On first launch, right-click the app → **Open** (it is ad-hoc signed, not
   notarized). If macOS still blocks it:

   ```bash
   xattr -d com.apple.quarantine /Applications/LirikTouchBar.app
   ```

### Build from source

Requires macOS 13+ and the Xcode command line tools.

```bash
git clone https://github.com/yourname/LirikTouchBar.git
cd LirikTouchBar
make build
open LirikTouchBar.app
```

Other targets: `make debug`, `make run`, `make install`, `make release`
(creates a versioned zip for a GitHub Release), `make clean`.

GitHub Actions builds and uploads a zip artifact on every push and pull request.

## First-run permissions

- **Automation → Spotify**: allow the prompt so the app can read the current
  track and playback position. The Spotify **desktop app** must be running
  (the web player is not supported).
- **Internet access**: needed for the first lyric lookup per track. Cached
  tracks work offline.
- **Login item**: optional, configurable in Preferences.

## Usage

- Menu bar icon — current lyric line; click for the menu.
- `⌥⌘L` — focus the Lyric Panel and activate the Touch Bar.
- Menu bar menu — Show Lyrics Panel, Play/Pause, Refresh Lyrics, Preferences, Quit.
- Preferences — refresh interval, Touch Bar font size, number of visible lines,
  menu-bar display, launch at login.

## Troubleshooting

- **Nothing appears to happen** — this is a menu-bar app. Look for the `♫`
  item in the top menu bar. The panel opens automatically on first launch.
- **Diagnostics** — `~/Library/Logs/LirikTouchBar.log` records Spotify reads,
  lyric lookups, the currently displayed line, and panel minimize/restore.
- **"Cannot reach Spotify"** — check System Settings → Privacy & Security →
  Automation, and make sure Spotify desktop is running.
- **"No synced lyrics found"** — LRCLIB is community sourced; coverage varies
  by track. The configured fallback text is shown instead.
- **Touch Bar shows function keys** — the Lyric Panel must be focused (or the
  app-level fallback active). Click the panel or press `⌥⌘L`.

## Project layout

```
Sources/LirikTouchBar/
├── LirikApp.swift                   app entry point (accessory / menu-bar app)
├── AppDelegate.swift                lifecycle, app-level Touch Bar, notifications
├── Models.swift                     Track, SpotifySnapshot, LyricLine
├── SpotifyService.swift             AppleScript polling + playback control
├── LyricsService.swift              LRCLIB client, LRC parser, local cache
├── LyricsController.swift           orchestration + position interpolation
├── TouchBarController.swift         NSTouchBar construction and updates
├── LyricPanelWindowController.swift focusable panel that owns the Touch Bar
├── StatusBarController.swift        menu bar item and menu
├── HotKeyManager.swift              ⌥⌘L global hotkey (Carbon)
├── AppSettings.swift                persisted preferences
├── SettingsView.swift               SwiftUI preferences + window
└── DebugLog.swift                   diagnostic logging
```

## Contributing

Issues and pull requests are welcome. Please keep changes on public Apple APIs
and include a short note in your PR about how you tested on real Touch Bar
hardware.

## License

[MIT](LICENSE) — see `LICENSE` for details.

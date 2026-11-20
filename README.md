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
- Shows lyrics on the Touch Bar with the lyric on the left and **previous /
  play-pause / next controls** on the right, plus a floating Lyric Panel.
- A compact **♪ menu-bar icon** gives quick access to Preferences and controls
  instead of printing the lyric across the top bar.
- Global hotkey `⌥⌘L` brings the Lyric Panel forward.
- Preferences for refresh interval, font size, visible lines, launch at login.
- Ships as a **universal binary** — runs natively on both Apple Silicon (M
  series) and Intel Macs. Requires macOS 13+.

## About the Touch Bar

Apple's public `NSTouchBar` API only draws an app's Touch Bar while **that app
is frontmost**. To keep lyrics visible while you use Spotify or any other app,
Lirik presents a **system-modal Touch Bar** using private AppKit / DFRFoundation
APIs (see `PrivateTouchBar.swift`). This bar stays on the physical Touch Bar
regardless of which app is focused, and regardless of whether the Lyric Panel
is minimized or hidden.

- The system bar has the **current lyric on the left** and three transport
  buttons on the right: `backward`, `play/pause` (icon follows playback state),
  and `forward`. They control Spotify directly.
- A **♪ button** is installed in the Touch Bar Control Strip. Tap it to hide or
  re-show the lyric bar. If it is missing, check
  System Settings → Keyboard → Touch Bar → **Show Control Strip**.
- The **menu bar** has a ♪ icon (with the current lyric as a hover tooltip).
  Click it for Preferences, playback controls, and the Touch Bar toggle.
- `⌥⌘L` focuses the Lyric Panel; it is optional — lyrics are already on the
  system bar.

> **Private API warning:** these APIs are undocumented, so this app cannot be
> distributed on the App Store and a future macOS update may break the
> system-modal bar. The menu bar and floating panel keep working in that case.

## Install

### From a release

1. Download `LirikTouchBar-vX.Y.Z.zip` from the
   [Releases](https://github.com/YOUR_USERNAME/LirikTouchBar/releases) page.
   See the full [installation tutorial](docs/INSTALL.md) for a step-by-step
   guide you can share with other people.
2. Unzip and drag `LirikTouchBar.app` into `/Applications`.
3. On first launch, right-click the app → **Open** (it is ad-hoc signed, not
   notarized). If macOS still blocks it:

   ```bash
   xattr -d com.apple.quarantine /Applications/LirikTouchBar.app
   ```

### Build from source

Requires macOS 13+ and the Xcode command line tools.

```bash
git clone https://github.com/YOUR_USERNAME/LirikTouchBar.git
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

- ♪ menu-bar icon — click for the menu; hover to see the current lyric.
- Menu items — Show Lyrics Panel, Show/Hide Touch Bar Lyrics, Play/Pause,
  Refresh Lyrics, Preferences…, Quit.
- `⌥⌘L` — focus the Lyric Panel (optional; lyrics are already on the system bar).
- Preferences — refresh interval, Touch Bar font size, number of visible lines,
  menu-bar display, launch at login.

## Troubleshooting

- **Nothing appears to happen** — this is a menu-bar app. Look for the `♪`
  icon in the top menu bar and click it for Preferences. The panel opens
  automatically on first launch.
- **Diagnostics** — `~/Library/Logs/LirikTouchBar.log` records Spotify reads,
  lyric lookups, the currently displayed line, and panel minimize/restore.
- **"Cannot reach Spotify"** — check System Settings → Privacy & Security →
  Automation, and make sure Spotify desktop is running.
- **"No synced lyrics found"** — LRCLIB is community sourced; coverage varies
  by track. The configured fallback text is shown instead.
- **Touch Bar shows function keys** — tap the ♪ Control Strip button, or check
  `~/Library/Logs/LirikTouchBar.log` for "System Touch Bar presented". If the
  private API was broken by a macOS update, use the floating Lyric Panel and
  the menu bar icon's hover tooltip.

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
├── PrivateTouchBar.swift            private system-modal Touch Bar APIs
├── SystemLyricsTouchBar.swift       always-on lyric bar + Control Strip button
├── AppSettings.swift                persisted preferences
├── SettingsView.swift               SwiftUI preferences + window
└── DebugLog.swift                   diagnostic logging
```

## Publishing a release (maintainers)

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Run `make release` — this builds a universal app and creates
   `LirikTouchBar-vX.Y.Z.zip`.
3. On GitHub, go to **Releases → Draft a new release**, create tag `vX.Y.Z`,
   attach the generated zip, and publish.
4. Share the [installation tutorial](docs/INSTALL.md) with users.

## Contributing

Issues and pull requests are welcome. If you change the Touch Bar behavior,
please test on real Touch Bar hardware (both Apple Silicon and Intel if
possible) and note it in your PR. Be aware that `PrivateTouchBar.swift` uses
undocumented APIs.

## License

[MIT](LICENSE) — see `LICENSE` for details.

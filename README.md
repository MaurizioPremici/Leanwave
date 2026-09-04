# Leanwave

Leanwave is a small native macOS player that streams audio from one YouTube page without keeping a browser-based video player open. It uses AppKit, `mpv`, and `yt-dlp`; it does not embed a browser, Electron, or a persistent web service.

## Requirements

- Apple Silicon Mac running macOS 15 or later
- Swift 6.1 or later
- Homebrew installations of `mpv` and `yt-dlp`

```bash
brew install mpv yt-dlp
```

## Build and install

```bash
swift test
./scripts/build-app.sh --install
open /Applications/Leanwave.app
```

The build script creates an ad-hoc signed bundle. Because Leanwave controls Chrome through Apple Events, macOS may ask you to allow Automation access the first time it fetches or closes a Chrome tab.

Leanwave explicitly runs `yt-dlp` without browser cookies. It therefore never asks Keychain for Chrome Safe Storage access. A short-lived loopback relay streams small byte ranges to `mpv`, then stops with playback; it is reachable only from the local Mac and stores no media.

## Use

Leanwave tries to fetch the active YouTube tab from Google Chrome when it opens. You can also type or paste a YouTube URL, or use **Fetch Again** after navigating Chrome to a different page. Playback never starts automatically.

The player provides play/pause, back and forward 15 seconds, timeline seeking, volume, mute, and stop. Once audio playback is confirmed, Leanwave asks whether to:

- **Close YouTube Tab** — close only the exact matching YouTube tab;
- **Quit Chrome** — quit Google Chrome completely;
- **Keep Open** — make no browser changes.

Leanwave never closes a tab or Chrome without this explicit choice. If a tab cannot be matched safely, it remains open.

## Themes

Choose Carbon, Arctic, Sunset, Forest, Violet, or Paper. Leanwave remembers the selected theme locally in macOS user defaults.

The compact player stays above ordinary application windows. Use the visible `−` and `×` controls to minimize or close it.

## Memory design

The interface is native AppKit and uses no remote images or decorative animation. Audio buffering is bounded in the `mpv` launch configuration. The app process and the separate `mpv` process should be measured independently when comparing memory use.

## Development

```bash
swift test
swift build -c release
./scripts/build-app.sh
```

Generated bundles and Swift build output are excluded from Git.

<h1 align="center">Kaset — Discord Rich Presence</h1>

<p align="center">A small fork of <a href="https://github.com/sozercan/kaset">Kaset</a> focused on Discord Rich Presence.</p>

> The original project, complete feature list, documentation, and installation information are available in the [upstream Kaset README](https://github.com/sozercan/kaset#readme).

## Why this fork

Kaset already provides a native YouTube Music experience on macOS. This fork keeps the upstream app as close to the original as possible while adding optional Discord Rich Presence for music playback.

When enabled, Discord can show:

- Current track
- Artist
- Album artwork
- Playback time
- A button to open the track on YouTube Music

## Using Discord Rich Presence

1. Open the Discord desktop app.
2. Open Kaset.
3. Go to **Settings → General → Discord**.
4. Enable **Share listening status on Discord**.
5. Start playing music.

No Discord Developer Portal setup is required. The public Discord Application ID used by this fork is already included in the app. No client secret, bot token, or user token is bundled.

If the activity does not appear, make sure **Discord → User Settings → Activity Privacy → Share your detected activities with others** is enabled.

## Install with Homebrew

```bash
brew tap codejota/tap
brew install --cask kaset-discord-rich-presence
```

The Homebrew cask installs this fork as **Kaset Discord.app**, so it can coexist with the upstream **Kaset.app**.

## Build from source

A full Xcode installation is required.

```bash
chmod +x Scripts/build-app.sh Scripts/compile_and_run.sh
KASET_SIGNING=adhoc ./Scripts/compile_and_run.sh --release
```

The built app will be available at:

```text
.build/app/Kaset.app
```

## Upstream

Kaset is developed by [sozercan](https://github.com/sozercan). For the original project and all features unrelated to this fork, see:

- [sozercan/kaset](https://github.com/sozercan/kaset)
- [Original README](https://github.com/sozercan/kaset#readme)

## Disclaimer

Kaset is an unofficial application and is not affiliated with YouTube, Google, or Discord.

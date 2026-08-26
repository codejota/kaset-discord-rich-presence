# Kaset — Discord Rich Presence

A fork of [Kaset](https://github.com/sozercan/kaset) focused on adding Discord Rich Presence while keeping the original application experience as intact as possible.

> For the original project, features and documentation, see the [upstream Kaset repository](https://github.com/sozercan/kaset).

## Why this fork?

Kaset already provides a great native YouTube Music experience for macOS!

This fork adds Discord Rich Presence so your current music can also appear on your Discord profile, including:

- Track title
- Artist
- Album artwork
- Playback progress
- Paused/playing state
- Link back to YouTube Music

No Discord configuration is required by the user.

## Install with Homebrew

This project is distributed through the Jotacode Homebrew tap.

```bash
brew tap codejota/tap
brew trust codejota/tap
brew install --cask kaset-discord-rich-presence
```

The `brew trust` command is required because this is a third-party Homebrew tap. It explicitly allows Homebrew to load Casks from this repository.

After installation, the app will be available as:

```text
/Applications/Kaset Discord.app
```

### Updating

```bash
brew update
brew upgrade --cask kaset-discord-rich-presence
```

### Uninstalling

```bash
brew uninstall --cask kaset-discord-rich-presence
```

## Original Kaset compatibility

This fork is intentionally kept separate from the original Kaset installation.

The original app can remain installed as:

```text
/Applications/Kaset.app
```

while this fork installs as:

```text
/Applications/Kaset Discord.app
```

The fork also uses its own bundle identifier and application data, so installing it should not overwrite the original Kaset installation.

## Discord Rich Presence

1. Open the Discord desktop app.
2. Open Kaset Discord.
3. Go to **Settings → General → Discord**.
4. Enable **Share listening status on Discord**.
5. Start playing music.

If your activity does not appear, check:

**Discord → Settings → Activity Privacy → Share your detected activities with others**

The Discord Application ID is already included in the app. Users do not need to create their own Discord Developer application.

No Discord client secret, bot token or user token is included.

## Manual installation

Prebuilt releases are also available from:

[GitHub Releases](https://github.com/codejota/kaset-discord-rich-presence/releases)

Download the latest `.dmg`, open it and move **Kaset Discord** to your Applications folder.

Because current releases are not notarized with an Apple Developer ID, macOS may display a security warning on first launch.

## Build from source

A full Xcode installation is required.

```bash
chmod +x Scripts/build-app.sh Scripts/compile_and_run.sh
KASET_SIGNING=adhoc ./Scripts/compile_and_run.sh --release
```

The generated application will be available at:

```text
.build/app/Kaset Discord.app
```

## Upstream

Kaset is originally developed by [sozercan](https://github.com/sozercan).

This repository only maintains the changes specific to this fork.

- [Original Kaset repository](https://github.com/sozercan/kaset)
- [Original Kaset README](https://github.com/sozercan/kaset#readme)

## Disclaimer

Kaset is an unofficial application and is not affiliated with YouTube, Google or Discord.

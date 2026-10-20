# music

A YouTube music player for the terminal. Type a search, it starts playing
immediately and keeps resolving the next songs in the background. No account,
no login, no browser, nothing written to disk.

```
$ music arijit singh

searching: arijit singh
now playing 1/12   0:42 / 4:12
  Arijit Singh: Har Har Gange With Lyrics | Batti Gul Meter Chalu
   next: Tum Hi Ho | Aashiqui 2 | Arijit Singh
```

## Why another one

Most terminal players are either full-screen TUIs that take over the terminal,
or they stop the music while you search for the next thing. This one is a
single bash script that:

- **streams** audio with `yt-dlp` + `mpv` — nothing is downloaded or cached to disk
- **pre-loads** the next 10 songs in the background, so track changes are instant
- **appends** to the terminal instead of redrawing it — no flicker, no escape
  codes, and the scrollback keeps a history of what you played
- **lets you search while it plays**: `music q <terms>` adds to the queue
  without interrupting the current song
- **restarts itself** if mpv dies mid-song (expired stream, 403, dropped network)
  instead of silently dropping you back to the shell

## Requirements

| tool | why |
| --- | --- |
| `mpv` | playback |
| `yt-dlp` | search + stream resolution |
| `socat` | talks to mpv over its JSON IPC socket |
| `jq` | parses the IPC replies |

Ubuntu/Debian:

```sh
sudo apt install mpv socat jq pipx
pipx install yt-dlp        # or: pip install --user -U yt-dlp
```

`yt-dlp` goes stale fast. Update it when YouTube breaks: `yt-dlp -U`.

## Install

```sh
git clone https://github.com/piyushkghosh/music.git
cd music
./install.sh
```

That copies the script to `~/.local/bin/music` (make sure that is on your
`PATH`). Or just `cp music ~/.local/bin/` yourself — there is no build step.

## Usage

```sh
music <terms>            # play a search right now
music --date <terms>     # same, but most recent uploads first
music q <terms>          # queue another search into the running player
music stop               # stop playback and clean up
```

Inside the player:

| key | action |
| --- | --- |
| `n` / `→` | next track |
| `p` / `←` | previous track |
| `space` | pause / resume |
| `m` | mute |
| `1` `2` `3` `9` | playback speed (1x, 2x, 3x, slow) |
| `:` | command line, e.g. `:mq lofi` to queue a new search |
| `q` | quit |

Starting a new `music <terms>` while one is already playing takes over the
player: the old one is stopped and the new search plays.

## Environment

| variable | default | meaning |
| --- | --- | --- |
| `MUSIC_VOL` | `70` | playback volume (0–130) |
| `MUSIC_FMT` | `251/140/b` | yt-dlp format preference |
| `MUSIC_FILTER` | unset | set to `1` to enable the optional ffmpeg filter chain |
| `MUSIC_LOG` | `~/.cache/music/mpv.log` | where mpv's output goes |

By default **no audio filters are applied**. YouTube's ceiling for anonymous
playback is 131 kbps Opus (`itag 251`), and every extra processing stage on top
of that only makes it worse. The filter chain is opt-in for people who want it.

## How it works

`yt-dlp` resolves a search to a list of YouTube watch URLs. The first is written
to a seed playlist and handed to `mpv`, which resolves the stream itself through
its own `ytdl_hook`. A background subshell resolves the rest in chunks of five
and appends them to the mpv playlist through the IPC socket as the queue drains,
so there are always `MUSIC_WIN` (10) songs ready. The UI is a plain read loop
that queries `playlist-pos`, `playlist-count`, `playback-time` and the track
list, then prints only when the current or next song changes.

State lives in `~/.cache/music/` and is removed on exit.

## Limitations

- The elapsed time in the "now playing" line is the position at the moment the
  track started; the UI is append-only and does not redraw.
- If mpv dies, the auto-restart replays from the seed track rather than resuming
  the exact second.
- Search results are whatever YouTube returns for the query — the same query can
  give a single, a lyric video, or a 3-hour jukebox re-upload. Different
  uploads are different masters; that is audible and not a bug in the player.
- 131 kbps Opus is the ceiling without an account. No client setting raises it.

## License

MIT

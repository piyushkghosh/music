#!/usr/bin/env bash
# install music and everything it needs, in one go.
#
#   ./install.sh                       # from a clone
#   curl -fsSL .../install.sh | bash   # standalone
#
# Missing packages are installed automatically: system packages through the
# platform's package manager (asking for sudo), yt-dlp as a single binary in
# ~/.local/bin so it can self-update without root.
set -u

REPO_RAW="${MUSIC_REPO_RAW:-https://raw.githubusercontent.com/piyushkghosh/music/main}"
DST_DIR="${PREFIX:-$HOME/.local/bin}"
DST="$DST_DIR/music"
ASSUME_YES="${ASSUME_YES:-0}"

say() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- source file
self_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  self_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi

src=""
if [ -n "$self_dir" ] && [ -f "$self_dir/music" ]; then
  src="$self_dir/music"
else
  have curl || { say "curl is required to download music"; exit 1; }
  tmp="$(mktemp)" || exit 1
  if curl -fsSL "$REPO_RAW/music" -o "$tmp"; then
    src="$tmp"
  else
    rm -f "$tmp"
    say "could not download music from $REPO_RAW"
    exit 1
  fi
fi

# ------------------------------------------------------------ system packages
sudo_cmd=""
if [ "$(id -u)" = 0 ]; then
  sudo_cmd=""
elif have sudo; then
  sudo_cmd="sudo"
fi

# install system packages with whichever manager exists; empty result = success
install_system_packages() {
  if have apt-get; then
    $sudo_cmd apt-get update -qq
    $sudo_cmd apt-get install -y "$@"
  elif have dnf; then
    $sudo_cmd dnf install -y "$@"
  elif have yum; then
    $sudo_cmd yum install -y "$@"
  elif have pacman; then
    $sudo_cmd pacman -Sy --noconfirm --needed "$@"
  elif have zypper; then
    $sudo_cmd zypper --non-interactive install "$@"
  elif have apk; then
    $sudo_cmd apk add --no-cache "$@"
  elif have brew; then
    brew install "$@"
  else
    return 1
  fi
}

pkg_missing=""
for tool in mpv socat jq; do
  have "$tool" || pkg_missing="$pkg_missing $tool"
done

if [ -n "$pkg_missing" ]; then
  say "installing:$pkg_missing"
  if [ -z "$sudo_cmd" ] && [ "$(id -u)" != 0 ] && ! have brew; then
    say "warning: sudo not available, cannot install:$pkg_missing"
    say "  install them yourself, then rerun this script"
  elif ! install_system_packages $pkg_missing; then
    say "warning: could not install:$pkg_missing (no supported package manager)"
  fi
else
  say "system packages: mpv, socat, jq already present"
fi

# -------------------------------------------------------------------- yt-dlp
# a single-file binary in ~/.local/bin, so it can update itself without root
refresh_ytdlp() {
  local target="$DST_DIR/yt-dlp" arch url tmpdir
  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    armv7l)        arch="armv7l" ;;
    *)             arch="" ;;
  esac
  if [ -z "$arch" ]; then
    say "warning: no prebuilt yt-dlp for $(uname -m); install it with pip"
    return 1
  fi
  url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
  [ "$arch" = "aarch64" ] && url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64"
  [ "$arch" = "armv7l" ]  && url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_armv7l"
  have curl || { say "warning: curl missing, cannot download yt-dlp"; return 1; }
  mkdir -p "$DST_DIR" || return 1
  say "downloading yt-dlp -> $target"
  if curl -fsSL "$url" -o "$target.part"; then
    chmod +x "$target.part"
    mv -f "$target.part" "$target"
    return 0
  fi
  rm -f "$target.part"
  say "warning: yt-dlp download failed"
  return 1
}

if have yt-dlp || [ -x "$HOME/.local/bin/yt-dlp" ]; then
  say "yt-dlp: $(command -v yt-dlp 2>/dev/null || echo "$HOME/.local/bin/yt-dlp")"
else
  refresh_ytdlp || {
    if have pipx; then say "trying pipx"; pipx install yt-dlp
    elif have pip3; then say "trying pip3 --user"; pip3 install --user -U yt-dlp
    fi
  }
fi

# ------------------------------------------------------------------ the script
mkdir -p "$DST_DIR" || { say "cannot create $DST_DIR"; exit 1; }
install -m 0755 "$src" "$DST" || { say "could not install to $DST"; exit 1; }
[ "$src" = "${tmp:-}" ] && rm -f "$src"
say "installed: $DST"

# ---------------------------------------------------------------- verification
problems=0
for tool in mpv socat jq; do
  have "$tool" || { say "still missing: $tool"; problems=1; }
done
if ! have yt-dlp && [ ! -x "$DST_DIR/yt-dlp" ]; then
  say "still missing: yt-dlp"
  problems=1
fi

case ":$PATH:" in
  *":$DST_DIR:"*) ;;
  *) say "note: $DST_DIR is not on your PATH - add it to ~/.bashrc:"
     say "  export PATH=\"$DST_DIR:\$PATH\"" ;;
esac

if [ "$problems" = 1 ]; then
  say ""
  say "music is installed but will not play until the missing tools above exist."
  exit 1
fi

say "done - try: music <song name>"

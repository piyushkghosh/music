#!/usr/bin/env bash
# install music into ~/.local/bin and check that its dependencies exist.
set -u

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/music"
dst_dir="${PREFIX:-$HOME/.local/bin}"
dst="$dst_dir/music"

missing=0
for tool in mpv socat jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'missing: %s\n' "$tool"; missing=1; }
done
if [ -x "$HOME/.local/bin/yt-dlp" ] || command -v yt-dlp >/dev/null 2>&1; then
  :
else
  printf 'missing: yt-dlp\n'
  missing=1
fi
if [ "$missing" = 1 ]; then
  printf '\ninstall the missing tools first, e.g. on Ubuntu:\n'
  printf '  sudo apt install mpv socat jq\n'
  printf '  pipx install yt-dlp\n\n'
  exit 1
fi

mkdir -p "$dst_dir" || exit 1
install -m 0755 "$src" "$dst" || exit 1
printf 'installed: %s\n' "$dst"

case ":$PATH:" in
  *":$dst_dir:"*) ;;
  *) printf 'note: %s is not on your PATH - add it to ~/.bashrc:\n' "$dst_dir"
     printf '  export PATH="$HOME/.local/bin:$PATH"\n' ;;
esac

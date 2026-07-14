#!/bin/sh
# Installs the starship-p10k-rainbow preset to your Starship config path,
# then checks its dependencies (git, starship, a Nerd Font) and prints the
# exact install command for your system when something is missing.
# It never runs sudo and never installs system packages on its own.
#
# Pipe it:
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/starship-p10k-rainbow/main/install.sh | sh
# Also install starship itself (official installer, no sudo, ~/.local/bin):
#   curl -sS https://raw.githubusercontent.com/carlosplanchon/starship-p10k-rainbow/main/install.sh | sh -s -- --install-starship
set -eu

RAW_TOML='https://raw.githubusercontent.com/carlosplanchon/starship-p10k-rainbow/main/starship.toml'
STARSHIP_INSTALLER='https://starship.rs/install.sh'
CONFIG="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"

say() { printf '%s\n' "$*"; }

INSTALL_STARSHIP=0
for arg in "$@"; do
  case "$arg" in
    --install-starship) INSTALL_STARSHIP=1 ;;
    -h|--help)
      say 'usage: install.sh [--install-starship]'
      say ''
      say 'Installs the preset to your Starship config path and reports any'
      say 'missing dependency with the install command for your system.'
      say ''
      say '  --install-starship  also run the official starship installer'
      say '                      (no sudo: installs into ~/.local/bin)'
      exit 0 ;;
    *) say "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  say 'error: need curl or wget to download the preset.' >&2
  exit 1
fi

# Detected once and used only to print accurate instructions, never to install.
if   command -v pacman  >/dev/null 2>&1; then PM=pacman
elif command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf     >/dev/null 2>&1; then PM=dnf
elif command -v brew    >/dev/null 2>&1; then PM=brew
else PM=unknown
fi

# ---------- install the preset ----------

# Download to temp files; the real config is only touched on success.
tmp=$(mktemp); inst=$(mktemp)
trap 'rm -f "$tmp" "$inst"' EXIT
fetch "$RAW_TOML" "$tmp"
grep -q 'starship.rs/config-schema' "$tmp" || {
  say 'error: downloaded file does not look like the preset; aborting.' >&2
  exit 1
}

# Timestamped backup: never clobbers a previous one.
if [ -f "$CONFIG" ]; then
  bak="$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG" "$bak"
  say "existing config backed up to: $bak"
fi

mkdir -p "$(dirname "$CONFIG")"
chmod 644 "$tmp"
mv "$tmp" "$CONFIG"
say "preset installed at: $CONFIG"

# ---------- dependency report ----------

say ''
say 'dependencies:'

if command -v git >/dev/null 2>&1; then
  say '  [ok] git'
else
  say '  [--] git: branch names still render without it, but the dirty-state'
  say '       subsegment silently disappears. Install it:'
  case $PM in
    pacman) say '         sudo pacman -S git' ;;
    apt)    say '         sudo apt install git' ;;
    dnf)    say '         sudo dnf install git' ;;
    brew)   say '         brew install git' ;;
    *)      say '         use your system package manager' ;;
  esac
fi

if command -v starship >/dev/null 2>&1; then
  say '  [ok] starship'
elif [ "$INSTALL_STARSHIP" -eq 1 ]; then
  say "  [..] starship: running the official installer (no sudo, into $HOME/.local/bin)"
  fetch "$STARSHIP_INSTALLER" "$inst"
  mkdir -p "$HOME/.local/bin"   # the official installer requires an existing dir
  sh "$inst" --yes --bin-dir "$HOME/.local/bin"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) say '       note: ~/.local/bin is not in your PATH; add it, e.g.:'
       # shellcheck disable=SC2016  # printed literally: a line for the user's shell config.
       say '         export PATH="$HOME/.local/bin:$PATH"' ;;
  esac
  say '       then set up its init line for your shell: https://starship.rs/guide/'
else
  say '  [--] starship: the prompt engine itself. Install it:'
  # apt intentionally falls through to the official script: Ubuntu only ships
  # starship from 25.10 (universe), and at an older version than this preset
  # is tested with. The official installer works everywhere and is current.
  case $PM in
    pacman) say '         sudo pacman -S starship' ;;
    dnf)    say '         sudo dnf install starship' ;;
    brew)   say '         brew install starship' ;;
    *)      say '         curl -sS https://starship.rs/install.sh | sh' ;;
  esac
  say '       or rerun this script with --install-starship (no sudo).'
  say '       then set up its init line for your shell: https://starship.rs/guide/'
fi

if command -v fc-list >/dev/null 2>&1; then
  if fc-list 2>/dev/null | grep -qi 'nerd'; then
    say '  [ok] Nerd Font (fontconfig): confirm the OS logos render below.'
  else
    say '  [--] Nerd Font (v3.0+): none detected via fontconfig. Install one:'
    case $PM in
      pacman) say '         sudo pacman -S ttf-nerd-fonts-symbols' ;;
      brew)   say '         brew install font-hack-nerd-font   # or any font-*-nerd-font' ;;
      *)      say '         https://www.nerdfonts.com/font-downloads' ;;
    esac
  fi
else
  say '  [??] Nerd Font (v3.0+): cannot auto-detect here; check the logos below.'
fi

say '       󰣇 󰕈 󰣚 󰣭  󰣛 󱄛   󰣨  󰐿 󰌽 󰀵 󰍲'
# shellcheck disable=SC2016  # $SHELL is meant literally: it's a command for the user to type.
say 'done. open a new shell (or run: exec $SHELL) to see the prompt.'

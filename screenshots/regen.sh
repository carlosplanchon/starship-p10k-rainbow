#!/usr/bin/env bash
# Regenerates every screenshot the README links to, using vhs: a real
# headless terminal running a real zsh with this repo's starship.toml.
# Each shot builds its own throwaway demo repo, so the output depends only
# on the preset and the pinned font/palette below.
#
#   ./regen.sh          rebuilds clean, dirty, detached, rebase, right and
#                       recomposes hero.png as hero-p10k.png + clean.png
#
# hero-p10k.png (the Powerlevel10k half of the hero shot) is the one manual
# asset: replace it with any 1150px-wide capture of p10k rainbow in a clean
# repo if you ever want to refresh it. Without it, hero.png is skipped.
#
# Needs: vhs, starship, zsh, git, python3, imagemagick, and the font below.
# The tapes are generated at runtime because they embed absolute paths.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TOML=$(cd "$HERE/.." && pwd)/starship.toml
FONT=${REGEN_FONT:-"JetBrainsMono Nerd Font"}

for dep in vhs starship zsh git magick; do
  command -v "$dep" >/dev/null || { echo "error: $dep not found" >&2; exit 1; }
done
PY=python3; command -v python3 >/dev/null || PY=python
command -v "$PY" >/dev/null || { echo "error: python3 not found (right.png needs a venv)" >&2; exit 1; }
[ -f "$TOML" ] || { echo "error: $TOML not found" >&2; exit 1; }
# No -q on this grep: with pipefail, grep -q's early exit can kill fc-list
# with SIGPIPE and turn a successful match into a failed pipeline.
if command -v fc-list >/dev/null && ! fc-list 2>/dev/null | grep -i "${FONT%% *}" >/dev/null; then
  echo "warning: font '$FONT' not found; set REGEN_FONT to an installed Nerd Font" >&2
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out"

# ---------- demo repos, one per shot (states from the old shot list) ----------

GITC=(-c user.name=demo -c user.email=demo@example.com -c commit.gpgsign=false)

mkbase() {
  mkdir -p "$1" && cd "$1"
  git init -qb main
  echo hello > app.py
  git add . && git "${GITC[@]}" commit -qm 'initial commit'
  git "${GITC[@]}" tag v1.0
}
for s in clean dirty detached rebase right; do mkbase "$WORK/states/$s/demo"; done

cd "$WORK/states/dirty/demo"    && echo more >> app.py && touch notes.txt
cd "$WORK/states/detached/demo" && git checkout -q v1.0
cd "$WORK/states/rebase/demo"   && {
  git checkout -qb feature main
  sed -i 's/hello/feature/' app.py && git "${GITC[@]}" commit -aqm feature
  git checkout -q main
  sed -i 's/hello/main/' app.py && git "${GITC[@]}" commit -aqm main
  git checkout -q feature
  git rebase main >/dev/null 2>&1 || true   # stops on the conflict, on purpose
}
cd "$WORK/states/right/demo" && "$PY" -m venv .venv

# ---------- tapes ----------

# vhs starts zsh without rc files; each tape types the prompt setup inside a
# Hide block, so it runs in-session and never appears in the capture.
# shellcheck disable=SC2016  # the $( ) must reach the tape unexpanded.
SETUP='export STARSHIP_CONFIG='"$TOML"' && eval "$(starship init zsh)"'
THEME='{ "name": "tango-dark", "black": "#2e3436", "red": "#cc0000", "green": "#4e9a06", "yellow": "#c4a000", "blue": "#3465a4", "purple": "#75507b", "cyan": "#06989a", "white": "#d3d7cf", "brightBlack": "#555753", "brightRed": "#ef2929", "brightGreen": "#8ae234", "brightYellow": "#fce94f", "brightBlue": "#729fcf", "brightPurple": "#ad7fa8", "brightCyan": "#34e2e2", "brightWhite": "#eeeeec", "background": "#000000", "foreground": "#babdb6", "selectionBackground": "#555753", "cursor": "#babdb6", "cursorAccent": "#000000" }'

tape_head() { # $1 name, $2 height
  cat <<EOF
Output out/$1.gif
Set Shell zsh
Set FontFamily "$FONT"
Set FontSize 24
Set Width 1150
Set Height $2
Set Padding 16
Set Theme $THEME
EOF
}

for s in clean dirty detached rebase; do
  { tape_head "$s" 120
    cat <<EOF
Hide
Type '$SETUP && cd $WORK/states/$s/demo && clear'
Enter
Sleep 2s
Show
Sleep 3s
Screenshot out/$s.png
EOF
  } > "$WORK/$s.tape"
done

{ tape_head right 170
  cat <<EOF
Hide
Type '$SETUP && cd $WORK/states/right/demo && source .venv/bin/activate && clear'
Enter
Sleep 2s
Show
Type "sleep 2"
Enter
Sleep 4s
Screenshot out/right.png
EOF
} > "$WORK/right.tape"

# ---------- record ----------

# vhs's Screenshot is occasionally not written; the gif always is, and Hide
# keeps setup out of it, so its last frame equals the wanted screenshot.
ensure_png() { # $1 name
  if [ ! -s "$WORK/out/$1.png" ]; then
    magick "$WORK/out/$1.gif" -coalesce "$WORK/out/_$1_%03d.png"
    frames=("$WORK/out/_$1_"*.png)
    cp "${frames[${#frames[@]}-1]}" "$WORK/out/$1.png"
    rm -f "$WORK/out/_$1_"*.png
  fi
}

cd "$WORK"
for s in clean dirty detached rebase right; do
  echo "recording $s..."
  vhs "$WORK/$s.tape" >/dev/null 2>&1
  ensure_png "$s"
  cp "$WORK/out/$s.png" "$HERE/$s.png"
done

# ---------- hero ----------

if [ -f "$HERE/hero-p10k.png" ]; then
  magick "$HERE/hero-p10k.png" "$HERE/clean.png" -append "$HERE/hero.png"
  echo "hero.png recomposed (p10k half from hero-p10k.png)"
else
  echo "warning: hero-p10k.png missing; hero.png left untouched" >&2
fi

echo "done: clean.png dirty.png detached.png rebase.png right.png"

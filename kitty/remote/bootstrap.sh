#!/bin/sh
# One-time remote environment bootstrap, synced by kitten ssh as ~/.zsh-bootstrap.sh.
# Installs everything into ~/.local and ~/.zsh — no root required. Idempotent:
# exits immediately once the done-marker exists. To re-run after a failure:
#   rm ~/.local/state/zsh-bootstrap.done && sh ~/.zsh-bootstrap.sh
set -u

STATE_DIR="$HOME/.local/state"
DONE="$STATE_DIR/zsh-bootstrap.done"
LOG="$STATE_DIR/zsh-bootstrap.log"
BIN="$HOME/.local/bin"
PLUG="$HOME/.zsh/plugins"

[ -f "$DONE" ] && exit 0
mkdir -p "$STATE_DIR" "$BIN" "$PLUG"
: > "$LOG"

say()  { printf '\033[1;35m[bootstrap]\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
fetch() {
  if have curl; then curl -fsSL "$1"
  else wget -qO- "$1"
  fi
}
download() {
  if have curl; then curl -fsSL -o "$2" "$1"
  else wget -qO "$2" "$1"
  fi
}

OS=$(uname -s)
ARCH=$(uname -m)
if [ "$OS" != "Linux" ]; then
  say "non-Linux host ($OS), skipping tool installs"
  touch "$DONE"
  exit 0
fi
case "$ARCH" in
  x86_64|amd64)  NVIM_ARCH=x86_64; EZA_ARCH=x86_64-unknown-linux-musl; BAT_ARCH=x86_64-unknown-linux-musl ;;
  aarch64|arm64) NVIM_ARCH=arm64;  EZA_ARCH=aarch64-unknown-linux-gnu; BAT_ARCH=aarch64-unknown-linux-gnu ;;
  *) say "unsupported arch $ARCH, skipping tool installs"; touch "$DONE"; exit 0 ;;
esac

if ! have curl && ! have wget; then
  say "neither curl nor wget available, cannot bootstrap"
  touch "$DONE"
  exit 0
fi

PATH="$BIN:$PATH"
say "setting up zsh environment on $(hostname) ($ARCH), log: $LOG"

# ── zsh (static build via romkatv/zsh-bin, no root) ─────────────────────────
if ! have zsh; then
  say "installing zsh -> ~/.local/bin/zsh"
  fetch https://raw.githubusercontent.com/romkatv/zsh-bin/master/install \
    | sh -s -- -d "$HOME/.local" -e no >>"$LOG" 2>&1 \
    || say "zsh install FAILED (see log)"
fi

# ── zsh plugins ──────────────────────────────────────────────────────────────
if have git; then
  for spec in \
    powerlevel10k=romkatv/powerlevel10k \
    zsh-autosuggestions=zsh-users/zsh-autosuggestions \
    fast-syntax-highlighting=zdharma-continuum/fast-syntax-highlighting \
    fzf-tab=Aloxaf/fzf-tab
  do
    name=${spec%%=*}; repo=${spec#*=}
    if [ ! -d "$PLUG/$name" ]; then
      say "cloning $name"
      git clone --quiet --depth=1 "https://github.com/$repo" "$PLUG/$name" >>"$LOG" 2>&1 \
        || say "clone of $name FAILED"
    fi
  done
else
  say "git not available, skipping zsh plugins"
fi

# ── fzf ──────────────────────────────────────────────────────────────────────
if ! have fzf; then
  if have git; then
    say "installing fzf"
    git clone --quiet --depth=1 https://github.com/junegunn/fzf "$HOME/.fzf" >>"$LOG" 2>&1 \
      && "$HOME/.fzf/install" --bin >>"$LOG" 2>&1 \
      && ln -sf "$HOME/.fzf/bin/fzf" "$BIN/fzf" \
      || say "fzf install FAILED"
  fi
fi

# ── zoxide ───────────────────────────────────────────────────────────────────
if ! have zoxide; then
  say "installing zoxide"
  fetch https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
    | sh >>"$LOG" 2>&1 || say "zoxide install FAILED"
fi

# ── eza ──────────────────────────────────────────────────────────────────────
if ! have eza; then
  say "installing eza"
  tmp=$(mktemp -d)
  if download "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz" "$tmp/eza.tgz" \
     && tar -xzf "$tmp/eza.tgz" -C "$tmp" >>"$LOG" 2>&1 \
     && find "$tmp" -name eza -type f -exec mv {} "$BIN/eza" \; \
     && [ -x "$BIN/eza" ]; then
    chmod +x "$BIN/eza"
  else
    say "eza install FAILED"
  fi
  rm -rf "$tmp"
fi

# ── bat ──────────────────────────────────────────────────────────────────────
if ! have bat; then
  say "installing bat"
  tag=$(fetch https://api.github.com/repos/sharkdp/bat/releases/latest \
        | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
  tmp=$(mktemp -d)
  if [ -n "$tag" ] \
     && download "https://github.com/sharkdp/bat/releases/download/${tag}/bat-${tag}-${BAT_ARCH}.tar.gz" "$tmp/bat.tgz" \
     && tar -xzf "$tmp/bat.tgz" -C "$tmp" >>"$LOG" 2>&1 \
     && mv "$tmp/bat-${tag}-${BAT_ARCH}/bat" "$BIN/bat"; then
    chmod +x "$BIN/bat"
  else
    say "bat install FAILED"
  fi
  rm -rf "$tmp"
fi

# ── neovim ───────────────────────────────────────────────────────────────────
if ! have nvim; then
  say "installing neovim"
  tmp=$(mktemp -d)
  if download "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" "$tmp/nvim.tgz" \
     && tar -xzf "$tmp/nvim.tgz" -C "$HOME/.local" >>"$LOG" 2>&1; then
    ln -sf "$HOME/.local/nvim-linux-${NVIM_ARCH}/bin/nvim" "$BIN/nvim"
    if ! "$BIN/nvim" --version >>"$LOG" 2>&1; then
      say "neovim binary does not run here (old glibc?), removing"
      rm -f "$BIN/nvim"
    fi
  else
    say "neovim install FAILED"
  fi
  rm -rf "$tmp"
fi

touch "$DONE"
say "done — failures (if any) are in $LOG; retry with: rm $DONE && sh ~/.zsh-bootstrap.sh"

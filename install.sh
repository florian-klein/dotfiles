#!/usr/bin/env bash
# Dotfiles installer — idempotent, safe to re-run.
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/florian-klein/dotfiles/main/install.sh | bash
#
# Steps: Xcode CLT -> Homebrew -> clone/update repo -> brew bundle ->
# symlink configs (existing files are backed up) -> shell plugin + cache setup.
# Skip package installs (e.g. for a quick re-link): DOTFILES_SKIP_BREW=1 ./install.sh
set -euo pipefail

REPO_URL="https://github.com/florian-klein/dotfiles.git"
DOTFILES="$HOME/dotfiles"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$HOME/.dotfiles-install.log"

# ── logging ──────────────────────────────────────────────────────────────────
log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; }
ok()   { printf '\033[1;32m[  ok  ]\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; }
warn() { printf '\033[1;33m[ warn ]\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; }
fail() { printf '\033[1;31m[ fail ]\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; exit 1; }

printf '== dotfiles install: %s ==\n' "$(date)" >> "$LOG_FILE"
[ "$(uname -s)" = "Darwin" ] || fail "this installer targets macOS"

# ── Xcode Command Line Tools (needed for git + Homebrew) ─────────────────────
if ! xcode-select -p >/dev/null 2>&1; then
  log "installing Xcode Command Line Tools (a dialog will open)…"
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
fi
ok "Xcode Command Line Tools present"

# ── Homebrew ─────────────────────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    log "installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || fail "Homebrew install failed"
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi
ok "Homebrew: $(brew --version | head -1)"

# ── Clone / update the repo ──────────────────────────────────────────────────
if [ -d "$DOTFILES/.git" ]; then
  log "updating existing repo in $DOTFILES"
  git -C "$DOTFILES" pull --ff-only || warn "could not fast-forward, using local state"
else
  log "cloning $REPO_URL"
  git clone --depth=1 "$REPO_URL" "$DOTFILES" || fail "clone failed"
fi

# ── Packages ─────────────────────────────────────────────────────────────────
if [ -z "${DOTFILES_SKIP_BREW:-}" ]; then
  log "installing packages from Brewfile (this can take a while)…"
  brew bundle --file="$DOTFILES/Brewfile" --no-upgrade \
    || warn "some Brewfile entries failed (already-installed apps/fonts are fine) — see $LOG_FILE"
  ok "packages installed"
else
  warn "DOTFILES_SKIP_BREW set, skipping package installs"
fi

# ── Symlinks (backs up anything that exists and isn't already a symlink) ─────
link() {
  local src="$DOTFILES/$1" dst="$HOME/$2"
  [ -e "$src" ] || { warn "missing in repo: $1"; return; }
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/"
    warn "backed up existing $2 -> $BACKUP/"
  fi
  ln -sfn "$src" "$dst"
  ok "linked ~/$2"
}

log "linking dotfiles…"
link zsh/zshrc            .zshrc
link zsh/zshrc.lazy       .zshrc.lazy
link zsh/zshenv           .zshenv
link zsh/zprofile         .zprofile
link zsh/p10k.zsh         .p10k.zsh
link tmux/tmux.conf       .tmux.conf
link kitty/kitty.conf     .config/kitty/kitty.conf
link kitty/current-theme.conf .config/kitty/current-theme.conf
link kitty/ssh.conf       .config/kitty/ssh.conf
link kitty/move_tab_to.py .config/kitty/move_tab_to.py
link kitty/remote         .config/kitty/remote
link bat/config           .config/bat/config
link atuin/config.toml    .config/atuin/config.toml
link nvim                 .config/nvim

# ── Shell plugins + caches ───────────────────────────────────────────────────
for plug in Aloxaf/fzf-tab romkatv/zsh-defer; do
  name="${plug##*/}"
  if [ ! -d "$HOME/.zsh/plugins/$name" ]; then
    log "cloning $name…"
    git clone --quiet --depth=1 "https://github.com/$plug" "$HOME/.zsh/plugins/$name" \
      || warn "$name clone failed"
  fi
done

log "generating shell init caches…"
mkdir -p "$HOME/.zsh_completions"
command -v fzf  >/dev/null && fzf --zsh > "$HOME/.zsh_completions/fzf.zsh" && ok "fzf cache"
command -v atuin >/dev/null && atuin init zsh --disable-up-arrow --disable-ai \
  > "$HOME/.zsh_completions/atuin.zsh" && ok "atuin cache"
command -v zoxide >/dev/null && zoxide init zsh > "$HOME/.zsh_completions/zoxide.zsh" && ok "zoxide cache"

log "byte-compiling zsh files (zcompile)…"
BP="$(brew --prefix)"
zsh -c '
for f in ~/.zshrc ~/.zshrc.lazy ~/.p10k.zsh ~/.zsh_completions/*.zsh \
         ~/.zsh/plugins/zsh-defer/zsh-defer.plugin.zsh \
         "'"$BP"'"/share/powerlevel10k/powerlevel10k.zsh-theme \
         "'"$BP"'"/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
         "'"$BP"'"/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh \
         ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh; do
  [[ -r $f ]] && zcompile -R -- "$f"
done' && ok "zsh files compiled (zsh falls back to source automatically if stale)"

[ -f "$HOME/.zshrc.local" ] || {
  printf '# Machine-local zsh config (untracked): SSH aliases, secrets, etc.\n' > "$HOME/.zshrc.local"
  ok "created empty ~/.zshrc.local"
}

# ── Done ─────────────────────────────────────────────────────────────────────
ok "install complete — log at $LOG_FILE"
[ -d "$BACKUP" ] && warn "previous configs preserved in $BACKUP"
log "next: restart kitty (or open it for the first time) and start a new shell"
log "nvim will install its plugins automatically on first launch"

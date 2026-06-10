# dotfiles

zsh + kitty + tmux + neovim setup for macOS. Warm Gruvbox accents on
white-on-black, powerlevel10k prompt, fzf-tab completion, atuin history,
and a kitten-ssh bootstrap that replicates the whole environment on any
Linux host you ssh into.

## Install (one-liner)

```sh
curl -fsSL https://raw.githubusercontent.com/florian-klein/dotfiles/main/install.sh | bash
```

Idempotent — safe to re-run. It installs Xcode CLT and Homebrew if missing,
installs all packages from the `Brewfile`, symlinks configs into `$HOME`
(backing up anything it would replace to `~/.dotfiles-backup-<timestamp>/`),
and generates the shell init caches. Steps are logged to
`~/.dotfiles-install.log`.

Re-link without touching packages:

```sh
DOTFILES_SKIP_BREW=1 ~/dotfiles/install.sh
```

## Layout

| Path | Linked to |
|---|---|
| `zsh/` | `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.p10k.zsh` |
| `kitty/` | `~/.config/kitty/` (conf, theme, ssh.conf, kittens) |
| `kitty/remote/` | dotfiles synced to every ssh host by kitten ssh |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `nvim/` | `~/.config/nvim` (plugins bootstrap on first launch) |
| `bat/`, `atuin/` | `~/.config/bat/config`, `~/.config/atuin/config.toml` |

Machine-specific things (SSH host aliases, secrets) belong in
`~/.zshrc.local`, which is sourced at the end of `.zshrc` and never tracked.

## Remote hosts

`kitten ssh` (aliased to `ssh` inside kitty) copies `kitty/remote/` configs
plus a bootstrap script to every Linux host on connect. First login installs
zsh, powerlevel10k + plugins, neovim, fzf, zoxide, eza, and bat into
`~/.local` — no root needed. See `kitty/remote/bootstrap.sh`.

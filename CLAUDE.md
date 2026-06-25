# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

```bash
make install          # link dotfiles + install packages
make link             # symlink dotfiles only (no package installation)
make install_packages # install Homebrew packages only
```

Requires Git and Make. `make copy` copies a few files (`.bashrc`, `/etc/paths`) that cannot be symlinked.

## Architecture

This repo manages dotfiles via **symlinks** on macOS and Linux. The authoritative mapping lives in `scripts/link.sh` (`DOTFILE_PAIRS`), an indexed array of `"src:dst"` pairs (bash 3.2 compatible — macOS ships with bash 3.2 so associative arrays are avoided) that maps repo-relative paths to their home directory destinations (e.g. `.gitconfig` → `~/.gitconfig`).

- `scripts/lib.sh` — shared utilities: `detect_platform` (sets `$PLATFORM` to `osx`/`linux`) and `log <level> <text>`
- `scripts/link.sh` — creates all symlinks; also handles an `OBSOLETED_PAIRS` list for cleanup of removed mappings. Each directory under `.claude/skills/` is auto-linked into `~/.claude/skills/<name>` so machine-local skills placed directly in `~/.claude/skills/` are left untouched
- `scripts/install_packages.sh` — installs Homebrew, then brew packages and casks; handles macOS/Linux branches
- `git-hooks/pre-commit` — Ruby script that blocks commits containing `binding.pry`, `debugger`, `focus: true`, `save_and_open_page`, or merge conflict markers

## Self-authored script language

Self-authored scripts under `.claude/` (hook helpers, skill helpers) and repo automation are written in **Ruby** by default, to keep a single runtime across the repo. Ruby is always available (managed via mise). `git-hooks/pre-commit` is Ruby; the `voicevox-speak` hook and the `report-session` skill scripts were ported from Python to Ruby for this reason — prefer Ruby for new scripts and don't introduce Python.

Breaking the Ruby default is fine in these cases:
- **Thin shell glue / triggers** where shell is the natural fit and there's little logic (e.g. the existing `.claude/hooks/report-session-*.sh` trigger wrappers).
- **Integration constraints** — the target tool only ships an SDK/library in another language, so that language is required.
- **Vendored / third-party scripts** — keep them in their original language; don't port for uniformity's sake.

When breaking the default, keep the logic minimal; if a script grows real logic, move it to Ruby.

## Key configurations

**`.claude/settings.json`** (symlinked to `~/.claude/settings.json`) — Claude Code configuration including:
- Permission allow/deny/ask lists for Bash commands and file reads (POST-style `curl`, `git checkout/switch/push/reset/rebase` are gated by `ask`)
- PostToolUse hooks: auto-formats `.rb`/`.rake` files via `.claude/hooks/ruby-format.rb` (uses `standardrb --fix` when `standard` is in the bundle, falls back to `rubocop -A`), runs `prettier --write` on `.md` files, and appends edited Ruby file paths to `~/.claude/recently_edited_files.txt`
- macOS notification hooks on Stop and Notification events via `osascript`
- `report-session` auto-suggest hooks (scripts in `.claude/hooks/`, referenced via `$HOME/.claude/hooks/...`): a `UserPromptSubmit` hook fires on user satisfaction/completion phrases (gated by transcript length), and a `PostToolUse` Bash hook fires on `git commit`/`push`; both inject `additionalContext` nudging Claude to offer running `/report-session`, with the final go/no-go left to the model
- Default model `opus[1m]`, `language: "日本語"`, `alwaysThinkingEnabled`, and enabled plugins (`ruby-lsp`, `skill-creator`, `frontend-design`, `security-guidance`)

**`.claude/hooks/`** (symlinked to `~/.claude/hooks`) — shell scripts invoked by the hooks in `settings.json`. Referenced as `$HOME/.claude/hooks/...` so settings.json stays independent of the repo location.

**`.claude/skills/<name>/SKILL.md`** — per-skill definitions auto-linked by `scripts/link.sh`. Add a new skill by creating a directory under `.claude/skills/` with a `SKILL.md`; running `make link` symlinks it into `~/.claude/skills/<name>` (no manual `DOTFILE_PAIRS` edit needed).

**`Gemfile`** — declares `gem "standard"` (standardrb). Dotfiles scripts are few and don't warrant maintaining a custom rubocop rule set; standardrb provides zero-config formatting. The `.vscode/settings.json` sets `rubyLsp.formatter: "standard"` so VSCode format-on-save also uses standardrb.

**`.config/mise/.config.toml`** — manages runtime versions for node, ruby, python, terraform, and claude via [mise](https://mise.jdx.dev/)

**`.gitconfig`** — notable aliases:
- `git aicommit` — generates a commit message via Claude CLI, then opens editor
- `git aa` / `git coo` / `git rr` / `git b-delete` — fzf-powered interactive git operations
- `git fmr` — fetch + rebase onto origin/main in one step

**`.zsh/.aliases.zsh`** — defines `cop` (runs rubocop on modified `.rb` files or diff from main), `gwt` (creates git worktree under `tmp/worktree/`), `rgt` (ripgrep TSV output for spreadsheets)

## Adding a new dotfile

1. Add the file to the repo
2. Add its `"src:dst"` mapping to `DOTFILE_PAIRS` in `scripts/link.sh` (skip this step for skills — directories under `.claude/skills/` are picked up automatically)
3. Run `make link` to apply

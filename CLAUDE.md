# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

```bash
make install          # link dotfiles + install packages
make link             # symlink dotfiles only (no package installation)
make install_packages # install Homebrew packages only
make doctor           # check symlinks and hook runtimes/scripts
make doctor-notify    # check notification command and send a test notification
make pull             # git pull, preserving skip-worktree local diffs
```

Requires Git and Make. `make copy` copies a few files (`.bashrc`, `/etc/paths`) that cannot be symlinked.

`make doctor` checks managed symlinks (including skills and the repo-root `AGENTS.md`) and the runtimes/scripts referenced by command hooks in the live Claude/Codex settings. Missing, broken, replaced, or misdirected links and unavailable runtimes/scripts cause a nonzero exit status. It reads the link inventory from `scripts/link.sh --list`, runs Ruby/Bash/sh runtime probes, and does not repair files or execute hooks. Direct interpreter/script commands are supported; other command forms are reported as unsupported. It does not check hook wiring parity, formatter dependencies, or actual hook delivery.

`make doctor-notify` diagnoses desktop notifications using the same Ruby runtime and helper as the hooks. It reports missing commands or notification failures with a nonzero exit status; normal hooks still skip these failures. A successful command does not guarantee visible delivery: check the test notification on screen (notification permissions / Do Not Disturb may suppress it).

On WSL, notifications use Windows PowerShell via `powershell.exe` and the [BurntToast module](https://github.com/Windos/BurntToast) (Windows interop and Windows PATH inheritance must be enabled). Install it once in **Windows PowerShell**, for the same Windows user used by WSL:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Repository PSGallery
```

`make doctor-notify` checks that BurntToast is available and imports successfully, prints the loaded version, and sends a test notification. Normal hooks put the agent name in the title. If missing, the diagnostic fails with the installation command; it never installs modules automatically. BurntToast handles the Windows notification API details; macOS and other Linux environments do not require it. The helper uses `-ExecutionPolicy RemoteSigned` for the notification process only, without changing persistent execution policy settings; Group Policy restrictions still apply. Run the diagnostic from a WSL terminal to check delivery; an agent sandbox may prevent Windows executable interop.

If `make doctor-notify` reports missing or disabled `binfmt WSLInterop`, save work in all WSL distributions, run `wsl --shutdown` from Windows PowerShell, then reopen WSL and retry. This stops all WSL distributions. The notification diagnostic checks both `WSLInterop` and suffixed registrations such as `WSLInterop-late`; restricted environments that cannot read these registrations also fail this check.

## Architecture

This repo manages dotfiles via **symlinks** on macOS and Linux. The authoritative mapping lives in `scripts/link.sh` (`DOTFILE_PAIRS`), an indexed array of `"src:dst"` pairs (bash 3.2 compatible — macOS ships with bash 3.2 so associative arrays are avoided) that maps repo-relative paths to their home directory destinations (e.g. `.gitconfig` → `~/.gitconfig`).

- `scripts/lib.sh` — shared utilities: `detect_platform` (sets `$PLATFORM` to `osx`/`linux`) and `log <level> <text>`
- `scripts/link.sh` — creates all symlinks; also handles an `OBSOLETED_PAIRS` list for cleanup of removed mappings. Each directory under `.agents/skills/` is auto-linked into both `~/.agents/skills/<name>` (canonical cross-agent location) and `~/.claude/skills/<name>` (bridge link — Claude Code only reads `~/.claude/skills`, verified 2026-09). Machine-local skills placed directly in either directory are left untouched
- `scripts/vendored_skills.rb` — manages third-party skills vendored via `gh skill install --pin` (`make skills-list` / `skills-check` / `skills-update`). See **Vendored third-party skills** below
- `scripts/install_packages.sh` — installs Homebrew, then runs `brew bundle` against the root `Brewfile`. Platform differences live in the Brewfile itself via `OS.mac?` / `OS.linux?` (casks are macOS-only)
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

- Permission allow/deny/ask lists for Bash commands and file reads (POST-style `curl` and `git push` are gated by `ask`; `git checkout/switch/reset/rebase` are in `allow`)
- PostToolUse hooks: auto-formats `.rb`/`.rake` files via `.claude/hooks/ruby-format.rb` (uses `standardrb --fix` when `standard` is in the bundle, falls back to `rubocop -A`), and `.md` files via `.claude/hooks/md-format.rb` (prettier). Format skipping is controlled by `.claude/hooks/format-skip.rb` — see **Formatter skip** below
- Desktop notification hooks on Stop and Notification events via `.claude/hooks/desktop-notify.rb` (`osascript` on macOS, Windows PowerShell on WSL, `notify-send` on other Linux environments; unavailable notifications are skipped)
- `report-session` auto-suggest hooks (scripts in `.claude/hooks/`, referenced via `$HOME/.claude/hooks/...`): a `UserPromptSubmit` hook fires on user satisfaction/completion phrases (gated by transcript length), and a `PostToolUse` Bash hook fires on `git commit`/`push`; both inject `additionalContext` nudging Claude to offer running `/report-session`, with the final go/no-go left to the model
- `language: "日本語"`, `alwaysThinkingEnabled`, and enabled plugins (`ruby-lsp`, `skill-creator`, `frontend-design`, `security-guidance`)

**PC-local settings in `settings.json`**: `settings.local.json` does not exist at the user layer (`~/.claude/`) — only at the project layer. To keep machine-specific values (model, extra plugins, etc.) out of git while keeping the symlink intact, this repo uses `git update-index --skip-worktree .claude/settings.json`. When committing a change to the shared portions, temporarily lift the flag:

```bash
git update-index --no-skip-worktree .claude/settings.json
git add -p .claude/settings.json   # stage only the shared hunks
git commit
git update-index --skip-worktree .claude/settings.json
```

The flag also blocks a plain `git pull` whenever the remote touched `settings.json`. Use `make pull` (`scripts/pull.rb`), which lifts the flag on every skip-worktree file, stashes the local diff, pulls, pops the stash, and re-sets the flag; on a pull failure or a stash-pop conflict it stops and prints the manual recovery commands instead of rolling back automatically.

**`.claude/hooks/`** (symlinked to `~/.claude/hooks`) — shell scripts invoked by the hooks in `settings.json`. Referenced as `$HOME/.claude/hooks/...` so settings.json stays independent of the repo location. `.codex/hooks.json` (symlinked to `~/.codex/hooks.json`) points at the same `$HOME/.claude/hooks/` scripts, so Codex shares them with no duplicated copies. Hook **wiring** (event / matcher / command entries) is the one thing that cannot be shared — Claude Code only reads hooks from `settings.json` and Codex only reads `hooks.json`, with no include mechanism in either. When adding, removing, or re-matching a hook, update both files (as of 2026-09 seven entries share the same wiring — the `Stop` desktop-notify entry differs only in its title argument, "Claude Code" vs "Codex" — and the `Notification` entries exist only in `settings.json`).

**Codex / cross-agent sharing** — Codex reuses the Claude assets instead of maintaining forks: `~/.codex/AGENTS.md` is a symlink to `.claude/CLAUDE.md`, the repo-root `AGENTS.md` is a symlink to `CLAUDE.md`, and skills have a single source in `.agents/skills/`. Only `.codex/hooks.json` is Codex-specific (the live `~/.codex/config.toml` is machine-local with credentials and stays out of the repo).

**Formatter skip** — `.claude/hooks/format-skip.rb` is a shared module that `ruby-format.rb` and `md-format.rb` both `require_relative`. Skip rules are evaluated in order:

| Flag                                     | Scope                                                    |
| ---------------------------------------- | -------------------------------------------------------- |
| `/tmp/.claude-skip-format`               | all formatters, session-wide                             |
| `/tmp/.claude-skip-format.<ext>`         | extension only, session-wide                             |
| `<repo>/.claude/skip-format`             | all formatters, project-wide (commit to share with team) |
| `<repo>/.claude/skip-format.local`       | all formatters, project-wide personal (gitignored)       |
| `<repo>/.claude/skip-format.<ext>`       | extension only, project-wide                             |
| `<repo>/.claude/skip-format.local.<ext>` | extension only, project-wide personal (gitignored)       |

`<repo>` is checked both as the worktree itself and as the main checkout (the parent of `git rev-parse --git-common-dir`). A gitignored `.local` flag is absent from a freshly created git worktree, so placing it once in the main checkout covers every worktree of that repository.

**`.agents/skills/<name>/SKILL.md`** — per-skill definitions auto-linked by `scripts/link.sh`. Add a new skill by creating a directory under `.agents/skills/` with a `SKILL.md`; running `make link` symlinks it into `~/.agents/skills/<name>` and `~/.claude/skills/<name>` (no manual `DOTFILE_PAIRS` edit needed). The canonical copy lives in `.agents/skills/` (cross-agent standard location; skills used to live in `.claude/skills/`), while the `~/.claude/skills` bridge link exists because Claude Code does not read `~/.agents/skills` directly.

**Vendored third-party skills** — skills written by others (e.g. `yomiyasu`) are not installed into `~/.claude/skills` directly and not tracked as submodules. They are copied into `.agents/skills/<name>/` with `gh skill install <owner/repo> <name> --pin <tag> --dir .agents/skills`, so they ride the same auto-link as self-authored skills, and the exact version is what the repo commits. A vendored skill is recognised by the `metadata.github-repo` / `github-pinned` / `github-tree-sha` keys that `gh skill` injects into the SKILL.md frontmatter; that frontmatter is the only lock record (no separate manifest). Rules:

- Never hand-edit a vendored skill. If something must change, change the pin or open an issue upstream; local edits would be silently overwritten by the next `skills-update`
- Upstream releases often (yomiyasu shipped v2.0.0 → v2.0.2 within four days of 2026-10) and its SKILL.md tells the agent to run its bundled Python scripts, so pins are deliberate: update with `make skills-update NAME=<skill> REF=<tag>`, read `git diff -- .agents/skills/<skill>` (scripts included), then commit. `make skills-check` reports pins that lag the latest GitHub release and exits nonzero when any do
- **No commit without a security review.** Neither GitHub nor `gh skill` verifies skill content (the installer says so), and a skill is both instructions the agent follows and code it runs with your permissions. Every `add` / `update` is followed by a review of the new tree before the commit, recorded in `.agents/vendored-skills-reviews.yml` (one entry per `skill` + `tree_sha`; `verdict` is `ok`, `ok-with-notes` or `rejected`, with `method` and free-text `notes`). `make skills-list` / `skills-check` match the installed tree SHA against that file and flag `UNREVIEWED`; the tree SHA, not the tag, is the key because a tag can be moved. A review covers at least: (1) scripts — network access, file writes/deletes and how their destinations are derived, subprocess/exec/eval and whether their inputs come from outside, environment variables read, obfuscation; (2) instruction files (SKILL.md, references) — actions outside the skill's stated role (settings, credentials, arbitrary file reads, git, outbound sends), overrides of user/CLAUDE.md instructions, hidden text (HTML comments, zero-width characters); (3) one real run in a scratch directory to observe what it actually writes. Delegate the reading to independent agents that must cite `file:line` for every finding and list what they could not verify; grep alone is not a review. On an update, the diff since the last reviewed tree is the minimum scope, the full tree the default
- A plain `gh skill update` does not touch the vendored copy: it does not list `yomiyasu` at all (`gh skill update yomiyasu --dry-run` answers "none of the specified skills are installed", verified 2026-10 with gh 2.101 — the symlinked directory is not scanned). The `make` target is the only update path
- The Ruby-by-default rule does not apply inside a vendored skill (see **Self-authored script language**)

**`Gemfile`** — declares `gem "standard"` (standardrb). Dotfiles scripts are few and don't warrant maintaining a custom rubocop rule set; standardrb provides zero-config formatting. The `.vscode/settings.json` sets `rubyLsp.formatter: "standard"` so VSCode format-on-save also uses standardrb.

**`.config/mise/.config.toml`** — manages runtime versions for node, ruby, python, terraform, and claude via [mise](https://mise.jdx.dev/)

**`.gitconfig`** — notable aliases:

- `git aicommit` — generates a commit message via Claude CLI, then opens editor
- `git aa` / `git coo` / `git rr` / `git b-delete` — fzf-powered interactive git operations
- `git fmr` — fetch + rebase onto origin/main in one step

**`.zsh/.aliases.zsh`** — defines `cop` (runs rubocop on modified `.rb` files or diff from main), `gwt` (creates git worktree under `tmp/worktree/`), `rgt` (ripgrep TSV output for spreadsheets)

## Adding a new dotfile

1. Add the file to the repo
2. Add its `"src:dst"` mapping to `DOTFILE_PAIRS` in `scripts/link.sh` (skip this step for skills — directories under `.agents/skills/` are picked up automatically)
3. Run `make link` to apply

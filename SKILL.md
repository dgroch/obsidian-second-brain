---
name: second-brain
description: Set up and manage an Obsidian-based Second Brain with PARA folder structure, automated Git sync, backups, and note templates. Use when the user wants to create a knowledge management system, sync their Obsidian vault with Git, set up automated backups, manage notes with the PARA method, or scaffold a new vault.
homepage: https://github.com/dgroch/obsidian-second-brain
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires": { "bins": ["git"] },
        "install":
          [
            {
              "id": "brew-obsidian-cli",
              "kind": "brew",
              "formula": "yakitrak/yakitrak/obsidian-cli",
              "bins": ["obsidian-cli"],
              "label": "Install obsidian-cli (brew)",
            },
          ],
      },
  }
---

# Second Brain

Manage an Obsidian vault as a personal knowledge system using the PARA method (Projects, Areas, Resources, Archive) with automated Git sync.

## When to use

- User wants to create or scaffold a new Second Brain / Obsidian vault
- User wants to sync their vault with Git automatically
- User wants to back up or restore their vault
- User asks about PARA method organization
- User wants to process their inbox or reorganize notes
- User wants to set up cron/systemd/launchd for vault sync

## When NOT to use

- General Obsidian plugin questions (use the `obsidian` skill)
- Reading/editing individual notes (just use file tools directly)
- Non-Obsidian knowledge management tools

## Vault structure

```
SecondBrain/            (vault root)
├── 0-Inbox/            Capture everything here first
├── 1-Projects/         Active, time-bound work
├── 2-Areas/            Ongoing responsibilities (health, career)
├── 3-Resources/        Reference material (books, articles)
├── 4-Archive/          Completed or inactive items
├── Templates/          Note templates
│   ├── Daily Note.md
│   ├── Project.md
│   ├── Meeting Notes.md
│   └── Book Notes.md
└── .obsidian/          Obsidian config
```

## Setup a new vault

Run the interactive installer:

```bash
chmod +x /path/to/second-brain/install.sh
/path/to/second-brain/install.sh
```

The installer prompts for vault path, Git remote, sync interval, and auto-sync method (cron, systemd timer, or launchd agent).

Or scaffold manually:

```bash
VAULT="$HOME/SecondBrain"
mkdir -p "$VAULT"/{0-Inbox,1-Projects,2-Areas,3-Resources,4-Archive,Templates}
cd "$VAULT" && git init -b main
```

## Locate existing vaults

If `obsidian-cli` is installed:

```bash
obsidian-cli print-default --path-only
```

Otherwise read `~/Library/Application Support/obsidian/obsidian.json` (macOS) or check common locations (`~/Documents`, `~/SecondBrain`, `~/Obsidian`).

## Git sync

Sync script supports one-shot and daemon modes:

```bash
# Sync now (pull + push)
scripts/sync.sh

# Pull only / push only
scripts/sync.sh --pull-only
scripts/sync.sh --push-only

# Continuous daemon (syncs every SYNC_INTERVAL minutes)
scripts/sync.sh --daemon
```

The sync script:
1. Pulls with rebase (auto-resolves conflicts by keeping local changes)
2. Stages all changes
3. Commits with timestamp and changed-file summary
4. Pushes with retry (exponential backoff, 3 attempts)
5. Logs to `~/.secondbrain/sync.log` with rotation

## Cron setup

```bash
# Every 10 minutes
crontab -l | { cat; echo "*/10 * * * * /path/to/scripts/sync.sh >> ~/.secondbrain/sync.log 2>&1"; } | crontab -
```

## Systemd timer (Linux)

```bash
# Created automatically by install.sh, or manually:
mkdir -p ~/.config/systemd/user
# Create secondbrain-sync.service and .timer, then:
systemctl --user enable --now secondbrain-sync.timer
```

## Backups

```bash
scripts/backup.sh                    # Default location (~/.secondbrain/backups/)
scripts/backup.sh /path/to/backups   # Custom location
```

Creates compressed `.tar.gz` archives. Keeps last 10 automatically.

## PARA workflow

```
Capture → 0-Inbox → Clarify → Organize (1-4) → Weekly Review → Archive
```

**Processing inbox items:** For each note in `0-Inbox/`, decide:
- Is it actionable with a deadline? → `1-Projects/`
- Is it an ongoing responsibility? → `2-Areas/`
- Is it reference material? → `3-Resources/`
- Is it done or no longer relevant? → `4-Archive/`

When using `obsidian-cli` to move notes, prefer `obsidian-cli move` over `mv` — it updates wikilinks automatically.

## OpenClaw cron (alternative to OS cron)

If the user runs OpenClaw with a gateway, use OpenClaw's built-in cron instead of OS-level cron:

```bash
openclaw cron add --every 10m --command "Run scripts/sync.sh to sync my vault"
openclaw cron list
```

This is preferred when the OpenClaw daemon is already running, as it provides logging, run history, and model-aware scheduling.

## Troubleshooting

Load `references/sync-troubleshooting.md` when the user reports sync issues (auth failures, merge conflicts, stuck locks, vault not found).

## PARA deep dive

Load `references/para-method.md` when the user asks for detailed PARA guidance, decision flowcharts, or weekly review process.

## Configuration

All settings in `.env` (or `~/.secondbrain/.env`):

| Variable | Default | Purpose |
|----------|---------|---------|
| VAULT_PATH | ~/SecondBrain | Vault location |
| GIT_REMOTE | — | Remote URL |
| GIT_BRANCH | main | Sync branch |
| SYNC_INTERVAL | 10 | Minutes between syncs |
| COMMIT_PREFIX | vault | Auto-commit prefix |
| AUTO_RESOLVE_CONFLICTS | true | Rebase conflict handling |
| NOTIFICATIONS | true | Desktop notifications |

# Second Brain Framework

A ready-to-use framework for building your personal knowledge management system with [Obsidian](https://obsidian.md) and Git. Free, open-source, and no vendor lock-in — just markdown files synced with version control.

## Features

- **PARA folder structure** — Organize notes into Projects, Areas, Resources, and Archive
- **Automated Git sync** — Auto-commit and push/pull your vault on a schedule
- **Cross-platform** — Works on macOS, Linux, and Windows (WSL)
- **Multiple sync backends** — Cron, systemd timers, or macOS launchd
- **Conflict resolution** — Automatic rebase-based conflict handling
- **Backup system** — Timestamped compressed backups with rotation
- **Starter templates** — Daily notes, projects, meetings, book notes
- **Zero dependencies** — Just Bash and Git

## Quick Start

```bash
# Clone this framework
git clone https://github.com/dgroch/obsidian-second-brain.git
cd obsidian-second-brain

# Run the interactive installer
chmod +x install.sh
./install.sh
```

The installer will walk you through:
1. Choosing your vault location
2. Connecting a Git remote
3. Setting up the folder structure
4. Configuring auto-sync (cron, systemd, or launchd)

## Project Structure

```
obsidian-second-brain/
├── install.sh              # Interactive setup wizard
├── .env.example            # Configuration template
├── scripts/
│   ├── sync.sh             # Git sync (one-shot or daemon)
│   ├── backup.sh           # Compressed vault backups
│   └── status.sh           # Vault status dashboard
└── vault-template/         # Copied into your vault on install
    ├── .obsidian/           # Sensible Obsidian defaults
    ├── 0-Inbox/             # Capture everything here
    ├── 1-Projects/          # Active projects with deadlines
    ├── 2-Areas/             # Ongoing responsibilities
    ├── 3-Resources/         # Reference material
    ├── 4-Archive/           # Completed/inactive items
    └── Templates/           # Note templates
        ├── Daily Note.md
        ├── Project.md
        ├── Meeting Notes.md
        └── Book Notes.md
```

## Usage

### Sync Commands

```bash
# Sync now (pull + push)
./scripts/sync.sh

# Pull only
./scripts/sync.sh --pull-only

# Push only
./scripts/sync.sh --push-only

# Run as background daemon (syncs every N minutes)
./scripts/sync.sh --daemon
```

### Backup

```bash
# Create a backup
./scripts/backup.sh

# Backup to custom location
./scripts/backup.sh /path/to/backups
```

Backups are compressed `.tar.gz` archives. The last 10 are retained automatically.

### Status

```bash
./scripts/status.sh
```

Shows vault stats, git status, recent sync logs, and cron job status.

## Configuration

All configuration lives in `.env` (created by the installer). You can also edit `~/.secondbrain/.env` for global access.

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_PATH` | `~/SecondBrain` | Absolute path to your vault |
| `GIT_REMOTE` | — | Git remote URL |
| `GIT_BRANCH` | `main` | Branch to sync |
| `SYNC_INTERVAL` | `10` | Minutes between auto-syncs |
| `COMMIT_PREFIX` | `vault` | Prefix for auto-commit messages |
| `AUTO_RESOLVE_CONFLICTS` | `true` | Auto-resolve merge conflicts |
| `NOTIFICATIONS` | `true` | Desktop notifications on sync |
| `LOG_FILE` | `~/.secondbrain/sync.log` | Sync log location |
| `LOG_MAX_SIZE` | `10` | Max log size in MB before rotation |

## The PARA Method

| Folder | Contains | When to Use |
|--------|----------|-------------|
| **0-Inbox** | Uncategorized captures | Just got an idea? Drop it here |
| **1-Projects** | Active, time-bound work | Has a deadline and clear outcome |
| **2-Areas** | Ongoing responsibilities | Health, finances, career, hobbies |
| **3-Resources** | Reference & interests | Book notes, articles, how-tos |
| **4-Archive** | Done or inactive | Project finished? Move it here |

### Workflow

```
Capture → Inbox → Clarify → Organize (PARA) → Review → Archive
```

**Weekly review checklist:**
- [ ] Process everything in Inbox
- [ ] Review active Projects — update status
- [ ] Check Areas — anything neglected?
- [ ] Archive completed projects

## Recommended Obsidian Plugins

These community plugins pair well with this framework:

| Plugin | Purpose |
|--------|---------|
| [Obsidian Git](https://github.com/Vinzent03/obsidian-git) | In-app Git integration (alternative to cron) |
| [Templater](https://github.com/SilentVoid13/Templater) | Advanced templates with dynamic values |
| [Dataview](https://github.com/blacksmithgu/obsidian-dataview) | Query your notes like a database |
| [Calendar](https://github.com/liamcain/obsidian-calendar-plugin) | Visual calendar for daily notes |
| [Kanban](https://github.com/mgmeyers/obsidian-kanban) | Kanban boards for project management |

## Sync Methods Comparison

| Method | Platform | Survives Reboot | Setup |
|--------|----------|----------------|-------|
| **Cron** | All | Yes | `crontab -e` |
| **Systemd timer** | Linux | Yes | `systemctl --user` |
| **launchd** | macOS | Yes | `~/Library/LaunchAgents/` |
| **Daemon mode** | All | No (manual) | `sync.sh --daemon` |
| **Obsidian Git plugin** | All | With Obsidian | In-app settings |

## Uninstall

```bash
# Remove cron job
crontab -l | grep -v "secondbrain\|sync.sh" | crontab -

# Remove systemd timer (Linux)
systemctl --user disable --now secondbrain-sync.timer
rm ~/.config/systemd/user/secondbrain-sync.*

# Remove launchd agent (macOS)
launchctl unload ~/Library/LaunchAgents/com.secondbrain.sync.plist
rm ~/Library/LaunchAgents/com.secondbrain.sync.plist

# Remove config
rm -rf ~/.secondbrain

# Your vault and its git history remain untouched
```

## License

MIT

# Second Brain Framework

An [OpenClaw](https://github.com/openclaw/openclaw)-native framework for building your personal knowledge management system with [Obsidian](https://obsidian.md) and Git. Free, open-source, and no vendor lock-in — just markdown files synced with version control.

Includes an OpenClaw skill (`SKILL.md`) so your AI assistant can help manage your vault, run syncs, organize notes, and guide you through the PARA workflow.

## Features

- **OpenClaw skill** — AI-assisted vault management, sync, and organization
- **PARA folder structure** — Organize notes into Projects, Areas, Resources, and Archive
- **Automated Git sync** — Auto-commit and push/pull your vault on a schedule
- **Cross-platform** — Works on macOS, Linux, and Windows (WSL)
- **Multiple sync backends** — Cron, systemd timers, or macOS launchd
- **Conflict resolution** — Automatic rebase-based conflict handling
- **Backup system** — Timestamped compressed backups with rotation
- **Starter templates** — Daily notes, projects, meetings, book notes
- **obsidian-cli integration** — Auto-detects vaults, safe note moves with link updates
- **Zero dependencies** — Just Bash and Git (obsidian-cli and OpenClaw optional)

## Quick Start

### Option 1: OpenClaw workspace skill (recommended)

```bash
# Clone into your OpenClaw workspace
cd ~/your-workspace
git clone https://github.com/dgroch/obsidian-second-brain.git

# OpenClaw auto-discovers the SKILL.md — just ask:
# "Set up my second brain" or "Sync my vault"
```

### Option 2: Standalone install

```bash
git clone https://github.com/dgroch/obsidian-second-brain.git
cd obsidian-second-brain
chmod +x install.sh
./install.sh
```

### Option 3: Install obsidian-cli (optional, enhances vault management)

```bash
brew install yakitrak/yakitrak/obsidian-cli
```

The installer will walk you through:
1. Choosing your vault location (auto-detected if `obsidian-cli` is installed)
2. Connecting a Git remote
3. Setting up the folder structure
4. Configuring auto-sync (cron, systemd, or launchd)

## Project Structure

```
obsidian-second-brain/
├── SKILL.md                # OpenClaw skill definition (auto-discovered)
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

## OpenClaw Integration

This project is an [OpenClaw](https://github.com/openclaw/openclaw) workspace skill. When this directory is in your workspace, OpenClaw automatically loads the `SKILL.md` and can:

### Power Pack (cron + connectors + synthesis)

This repo also includes an **OpenClaw Power Pack** that mirrors the "production" automation used to feed and synthesise Dan's SecondBrain:

- Cron job templates: `openclaw/cron/jobs.template.json`
- Skills bundle: `openclaw/skills/`
  - `secondbrain-manager` (capture + synthesis routines)
  - `obsidian-git-bridge` (Obsidian Sync ↔ Git mirroring)
  - `trello` (Trello automation)
- MCP server bundle: `openclaw/mcp-servers/secondbrain-memory`

Install into an OpenClaw workspace:

```bash
bash openclaw/install-openclaw-power-pack.sh
```

- **Scaffold a new vault** with PARA folders and templates
- **Run Git sync** on demand or configure scheduled sync
- **Organize notes** using the PARA method (move notes between folders)
- **Process your inbox** — help you clarify and categorize captured notes
- **Create backups** and show vault status
- **Move/rename notes** safely via `obsidian-cli` (updates wikilinks)

The skill requires `git` and optionally `obsidian-cli` (installed via `brew install yakitrak/yakitrak/obsidian-cli`).

### Example OpenClaw prompts

- "Set up a new second brain in ~/Documents/Brain"
- "Sync my vault"
- "Help me process my inbox"
- "Back up my vault"
- "How many notes do I have?"
- "Move my 'Q1 Planning' project to the archive"

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

---
name: obsidian-git-bridge
description: >
  Maintain and troubleshoot a bridge between an Obsidian Sync vault and a Git
  repository using the obsidian-headless CLI plus a sync script. Use when:
  reviewing or updating bridge paths for this environment, cloning or wiring the
  Second Brain repo, setting up obsidian-headless and the local vault, adjusting
  sync frequency, changing exclude patterns, checking sync status, or
  reconfiguring the bridge service/timer.
---

# Obsidian ↔ Git Bridge

## Architecture

```
iOS Obsidian ↔ Obsidian Sync Cloud ↔ Server (ob headless) ↔ Git/GitHub
Desktop Obsidian ↔ Obsidian Sync Cloud ↗
```

- Server runs `obsidian-headless` as a third Obsidian Sync client
- Every 5 minutes: pull Obsidian Cloud → rsync to git → commit + push → rsync back → push to Obsidian Cloud
- User devices never touch git — Obsidian Cloud handles device sync
- Server-generated files (Fireflies transcripts, comms feed) flow to Obsidian via git → bridge

## Key Paths

| What | Path |
|------|------|
| Obsidian vault (local) | `/data/.openclaw/obsidian-sync` |
| Git repo | `/data/.openclaw/workspace/secondbrain` |
| Bridge script | `/data/.openclaw/workspace/skills/obsidian-git-bridge/scripts/obsidian-git-bridge.sh` |
| Systemd timer | `/etc/systemd/system/obsidian-git-bridge.timer` |
| Systemd service | `/etc/systemd/system/obsidian-git-bridge.service` |

## Current Environment Notes

- This environment does **not** currently have `ob` / `obsidian-headless` on PATH.
- The local vault directory does **not** currently exist.
- The Git repo target should be `secondbrain` inside `/data/.openclaw/workspace`, not `secondbrain-sync`.
- If the GitHub repository is private, clone/push requires GitHub credentials in this environment.

## Obsidian Account

- Email: `daniel.groch@hey.com`
- Vault: `SecondBrain` (ID: `3a565e06d5e2d884f35d6b44f9887ff5`, region: Oceania)
- Device name: `alfred-server`
- Encryption: uses account password

## Common Operations

### Check sync status
```bash
systemctl status obsidian-git-bridge.timer
journalctl -u obsidian-git-bridge.service --since "1 hour ago"
```

### Force immediate sync
```bash
systemctl start obsidian-git-bridge.service
```

### Change sync frequency
Edit `/etc/systemd/system/obsidian-git-bridge.timer`, change `OnUnitActiveSec=300` (seconds), then:
```bash
systemctl daemon-reload && systemctl restart obsidian-git-bridge.timer
```

### Clear stale lock
```bash
rm -rf /data/.openclaw/obsidian-sync/.obsidian/.sync.lock
```

### Manual Obsidian sync
```bash
cd /data/.openclaw/obsidian-sync && ob sync
```

### Re-login (if session expires)
```bash
ob login --email daniel.groch@hey.com --password '<password>'
```

## Sync Direction Rules

- **Obsidian → Git**: Obsidian is source of truth for user-edited files. Uses `rsync --delete`.
- **Git → Obsidian**: Server-generated files only. Uses `rsync --update` (newer wins, no delete).
- **Excluded from sync**: Server-only paths (scripts, vector store, binaries, MCP servers). See bridge script for full exclude list.

## Conflict Strategy

- Obsidian Sync: `merge` (Obsidian's built-in conflict resolution)
- Git: latest commit wins (force-push if needed for corrections)
- If a file is corrupted: restore from git history, push through both directions

## Troubleshooting

### "Another sync instance is already running"
```bash
rm -rf /data/.openclaw/obsidian-sync/.obsidian/.sync.lock
```

### Obsidian overwrites git with stale data
Obsidian Cloud may have a stale version. Fix: write correct file to both locations, push git, then `ob sync`.

### Files deleted that shouldn't be
Check the exclude list in the bridge script. Server-only files must be excluded from the Obsidian → Git rsync.

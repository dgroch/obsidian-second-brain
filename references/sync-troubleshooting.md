# Sync Troubleshooting

Common issues and solutions for Git-based vault sync.

## Authentication failures

**Problem:** `fatal: Authentication failed` on push/pull

**Solutions:**
- HTTPS: set up a personal access token or credential helper
  ```bash
  git config --global credential.helper store   # plaintext (simple)
  git config --global credential.helper osxkeychain  # macOS
  ```
- SSH: ensure key is added to ssh-agent
  ```bash
  ssh-add ~/.ssh/id_ed25519
  ssh -T git@github.com   # test connection
  ```

## Merge conflicts

**Problem:** `CONFLICT (content): Merge conflict in ...`

**With AUTO_RESOLVE_CONFLICTS=true:** the sync script keeps local changes and continues. Check your notes afterward.

**Manual resolution:**
```bash
cd /path/to/vault
git status                    # see conflicted files
# Edit files to resolve conflicts (remove <<<< ==== >>>> markers)
git add -A
git rebase --continue
```

## Sync not running

**Check cron:**
```bash
crontab -l | grep sync       # is the job listed?
```

**Check systemd (Linux):**
```bash
systemctl --user status secondbrain-sync.timer
journalctl --user -u secondbrain-sync.service --since "1 hour ago"
```

**Check launchd (macOS):**
```bash
launchctl list | grep secondbrain
cat ~/Library/LaunchAgents/com.secondbrain.sync.plist
```

**Check logs:**
```bash
tail -50 ~/.secondbrain/sync.log
```

## Large files slowing sync

Add large files to `.gitignore` in your vault:
```
*.pdf
*.mp4
*.zip
Attachments/*.png
```

Or use Git LFS for binary assets:
```bash
git lfs install
git lfs track "*.pdf"
```

## Lock file stuck

If sync reports "Another sync is running" but nothing is actually running:
```bash
rm ~/.secondbrain/sync.lock
```

## Vault not found

The sync script looks for VAULT_PATH in this order:
1. `.env` in the framework directory
2. `~/.secondbrain/.env`
3. `obsidian-cli print-default --path-only` (if installed)
4. Falls back to `~/SecondBrain`

Verify your vault path:
```bash
cat ~/.secondbrain/.env | grep VAULT_PATH
ls -la "$(grep VAULT_PATH ~/.secondbrain/.env | cut -d'"' -f2)"
```

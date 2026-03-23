#!/usr/bin/env bash
#
# status.sh - Show the current status of your Second Brain
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load configuration
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a; source "$ROOT_DIR/.env"; set +a
elif [[ -f "$HOME/.secondbrain/.env" ]]; then
    set -a; source "$HOME/.secondbrain/.env"; set +a
fi

VAULT_PATH="${VAULT_PATH:-$HOME/SecondBrain}"

echo "=== Second Brain Status ==="
echo ""

# Vault info
if [[ -d "$VAULT_PATH" ]]; then
    echo "Vault path:  $VAULT_PATH"
    note_count=$(find "$VAULT_PATH" -name "*.md" -not -path "*/.git/*" -not -path "*/.trash/*" | wc -l)
    echo "Total notes: $note_count"

    # Folder breakdown
    echo ""
    echo "--- Folder Breakdown ---"
    for folder in "0-Inbox" "1-Projects" "2-Areas" "3-Resources" "4-Archive" "Templates"; do
        if [[ -d "$VAULT_PATH/$folder" ]]; then
            count=$(find "$VAULT_PATH/$folder" -name "*.md" | wc -l)
            printf "  %-15s %d notes\n" "$folder" "$count"
        fi
    done
else
    echo "Vault: NOT FOUND at $VAULT_PATH"
fi

echo ""

# Git status
if [[ -d "$VAULT_PATH/.git" ]]; then
    cd "$VAULT_PATH"
    echo "--- Git Status ---"
    echo "Branch:      $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Remote:      $(git remote get-url origin 2>/dev/null || echo 'not set')"

    local_changes=$(git status --porcelain 2>/dev/null | wc -l)
    echo "Uncommitted: $local_changes files"

    last_sync=$(git log -1 --format="%ar" 2>/dev/null || echo "never")
    echo "Last sync:   $last_sync"
else
    echo "Git: NOT INITIALIZED"
fi

echo ""

# Sync status
LOG_FILE="${LOG_FILE:-$HOME/.secondbrain/sync.log}"
if [[ -f "$LOG_FILE" ]]; then
    echo "--- Recent Sync Log ---"
    tail -5 "$LOG_FILE"
fi

# Cron status
echo ""
echo "--- Cron Jobs ---"
if crontab -l 2>/dev/null | grep -q "secondbrain\|sync.sh"; then
    crontab -l 2>/dev/null | grep "secondbrain\|sync.sh"
else
    echo "No cron jobs configured. Run 'install.sh' to set up."
fi

#!/usr/bin/env bash
#
# backup.sh - Create a timestamped backup of your vault
#
# Usage:
#   backup.sh                    # Backup to default location
#   backup.sh /path/to/backup    # Backup to custom location
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
BACKUP_DIR="${1:-$HOME/.secondbrain/backups}"

if [[ ! -d "$VAULT_PATH" ]]; then
    echo "ERROR: Vault not found at $VAULT_PATH"
    exit 1
fi

timestamp="$(date '+%Y%m%d_%H%M%S')"
backup_name="secondbrain_backup_${timestamp}"
backup_path="$BACKUP_DIR/$backup_name"

mkdir -p "$BACKUP_DIR"

echo "Backing up vault to $backup_path..."

# Create tar archive excluding .git
tar -czf "${backup_path}.tar.gz" \
    --exclude='.git' \
    --exclude='.trash' \
    --exclude='.DS_Store' \
    -C "$(dirname "$VAULT_PATH")" \
    "$(basename "$VAULT_PATH")"

echo "Backup complete: ${backup_path}.tar.gz"
echo "Size: $(du -h "${backup_path}.tar.gz" | cut -f1)"

# Clean up old backups (keep last 10)
cd "$BACKUP_DIR"
ls -t secondbrain_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

backup_count=$(ls -1 secondbrain_backup_*.tar.gz 2>/dev/null | wc -l)
echo "Backups retained: $backup_count"

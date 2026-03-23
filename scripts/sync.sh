#!/usr/bin/env bash
#
# sync.sh - Automatically sync your Obsidian vault with Git
#
# Usage:
#   sync.sh              # Run once
#   sync.sh --daemon     # Run continuously at SYNC_INTERVAL
#   sync.sh --pull-only  # Only pull remote changes
#   sync.sh --push-only  # Only push local changes
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load configuration
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
elif [[ -f "$HOME/.secondbrain/.env" ]]; then
    set -a
    source "$HOME/.secondbrain/.env"
    set +a
else
    echo "ERROR: No .env file found. Run 'install.sh' first or copy .env.example to .env"
    exit 1
fi

# Defaults
VAULT_PATH="${VAULT_PATH:-$HOME/SecondBrain}"
GIT_BRANCH="${GIT_BRANCH:-main}"
COMMIT_PREFIX="${COMMIT_PREFIX:-vault}"
AUTO_RESOLVE_CONFLICTS="${AUTO_RESOLVE_CONFLICTS:-true}"
LOG_FILE="${LOG_FILE:-$HOME/.secondbrain/sync.log}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10}"
NOTIFICATIONS="${NOTIFICATIONS:-true}"
SYNC_INTERVAL="${SYNC_INTERVAL:-10}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# --- Logging ---

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

rotate_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        local size_mb
        size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)
        if [[ "$size_mb" -ge "$LOG_MAX_SIZE" ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log "INFO" "Log rotated"
        fi
    fi
}

notify() {
    local msg="$1"
    if [[ "$NOTIFICATIONS" != "true" ]]; then
        return
    fi
    case "$(uname -s)" in
        Darwin)
            osascript -e "display notification \"$msg\" with title \"Second Brain\"" 2>/dev/null || true
            ;;
        Linux)
            notify-send "Second Brain" "$msg" 2>/dev/null || true
            ;;
    esac
}

# --- Lock file to prevent concurrent syncs ---

LOCK_FILE="$HOME/.secondbrain/sync.lock"

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$lock_pid" 2>/dev/null; then
            log "WARN" "Another sync is running (PID $lock_pid), skipping"
            return 1
        else
            log "WARN" "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# --- Core sync functions ---

check_vault() {
    if [[ ! -d "$VAULT_PATH" ]]; then
        log "ERROR" "Vault not found at $VAULT_PATH"
        exit 1
    fi
    if [[ ! -d "$VAULT_PATH/.git" ]]; then
        log "ERROR" "Vault is not a git repository. Run 'install.sh' first."
        exit 1
    fi
}

pull_changes() {
    log "INFO" "Pulling remote changes..."
    cd "$VAULT_PATH"

    if [[ "$AUTO_RESOLVE_CONFLICTS" == "true" ]]; then
        if ! git pull --rebase origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
            log "WARN" "Rebase conflict detected, attempting auto-resolution..."
            # Accept local changes on conflict
            git checkout --theirs . 2>/dev/null || true
            git add -A
            git rebase --continue 2>/dev/null || git rebase --abort
            log "WARN" "Conflict resolved (kept local changes). Check your notes."
            notify "Sync conflict resolved - please review your notes"
        fi
    else
        if ! git pull --rebase origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
            log "ERROR" "Pull failed with conflicts. Resolve manually."
            git rebase --abort 2>/dev/null || true
            notify "Sync failed - manual conflict resolution needed"
            return 1
        fi
    fi
    log "INFO" "Pull complete"
}

push_changes() {
    cd "$VAULT_PATH"

    # Check for changes
    if git diff --quiet HEAD 2>/dev/null && [[ -z "$(git status --porcelain)" ]]; then
        log "INFO" "No changes to push"
        return 0
    fi

    log "INFO" "Pushing local changes..."

    # Stage all changes
    git add -A

    # Create commit with timestamp
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M')"
    local changed_files
    changed_files="$(git diff --cached --name-only | head -5 | tr '\n' ', ')"
    git commit -m "${COMMIT_PREFIX}: auto-sync ${timestamp}" \
                -m "Changed: ${changed_files%,}" 2>&1 | tee -a "$LOG_FILE"

    # Push with retry
    local retries=0
    local max_retries=3
    while [[ $retries -lt $max_retries ]]; do
        if git push origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
            log "INFO" "Push complete"
            notify "Vault synced successfully"
            return 0
        fi
        retries=$((retries + 1))
        local wait=$((2 ** retries))
        log "WARN" "Push failed, retrying in ${wait}s (attempt $retries/$max_retries)"
        sleep "$wait"
    done

    log "ERROR" "Push failed after $max_retries attempts"
    notify "Sync push failed after retries"
    return 1
}

do_sync() {
    rotate_logs
    check_vault

    if ! acquire_lock; then
        return 0
    fi
    trap release_lock EXIT

    local mode="${1:-full}"

    case "$mode" in
        pull)
            pull_changes
            ;;
        push)
            push_changes
            ;;
        full)
            pull_changes
            push_changes
            ;;
    esac

    release_lock
    trap - EXIT
    log "INFO" "Sync complete"
}

# --- Main ---

main() {
    local mode="full"
    local daemon=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --daemon)
                daemon=true
                shift
                ;;
            --pull-only)
                mode="pull"
                shift
                ;;
            --push-only)
                mode="push"
                shift
                ;;
            --help|-h)
                echo "Usage: sync.sh [--daemon] [--pull-only] [--push-only]"
                echo ""
                echo "Options:"
                echo "  --daemon      Run continuously at SYNC_INTERVAL (default: ${SYNC_INTERVAL}m)"
                echo "  --pull-only   Only pull remote changes"
                echo "  --push-only   Only push local changes"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ "$daemon" == "true" ]]; then
        log "INFO" "Starting sync daemon (interval: ${SYNC_INTERVAL}m)"
        while true; do
            do_sync "$mode" || true
            sleep $((SYNC_INTERVAL * 60))
        done
    else
        do_sync "$mode"
    fi
}

main "$@"

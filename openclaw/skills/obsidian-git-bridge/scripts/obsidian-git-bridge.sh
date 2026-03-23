#!/bin/bash
# Obsidian ↔ Git Bridge
# Syncs an Obsidian Sync vault to/from the secondbrain git repo in this environment.
#
# Flow:
#   1. ob sync (pull latest from Obsidian Cloud)
#   2. rsync Obsidian → Git (new/changed files from Obsidian)
#   3. rsync Git → Obsidian (new/changed files from Git, e.g. generated notes)
#   4. git commit + push any changes
#   5. ob sync (push changes back to Obsidian Cloud)
#
# Excludes: .obsidian/, .git/, .trash/

set -euo pipefail

export PATH="/data/.npm-global/bin:/data/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

OB_VAULT="/data/.openclaw/obsidian-sync"
GIT_REPO="/data/.openclaw/workspace/secondbrain"
LOG_TAG="[obsidian-git-bridge]"

if ! command -v ob >/dev/null 2>&1; then
  echo "$LOG_TAG ERROR: 'ob' not found on PATH" >&2
  exit 1
fi

log() { echo "$LOG_TAG $(date '+%H:%M:%S') $*"; }

run_ob_sync() {
  local phase="$1"
  local attempts=3
  local i=1
  cd "$OB_VAULT"
  while [ "$i" -le "$attempts" ]; do
    rm -rf .obsidian/.sync.lock 2>/dev/null || true
    log "$phase (attempt $i/$attempts)..."
    local out
    out="$(ob sync 2>&1 | tail -20 || true)"
    printf '%s
' "$out"
    if ! printf '%s' "$out" | grep -qi 'Another sync instance is already running'; then
      return 0
    fi
    log "Obsidian sync lock/race detected; sleeping before retry..."
    sleep 5
    i=$((i+1))
  done
  return 1
}

file_fingerprint() {
  local file="$1"
  if [ -f "$file" ]; then
    sha256sum "$file" | awk '{print $1 "  " FILENAME}' FILENAME="$file"
  else
    echo "MISSING  $file"
  fi
}

# 1. Pull from Obsidian Cloud
log "Pulling from Obsidian Sync..."
run_ob_sync "Obsidian pull"
log "Obsidian pull complete."

# Shared excludes
EXCLUDES=(
  --exclude='.obsidian/'
  --exclude='.git/'
  --exclude='.trash/'
  --exclude='.gitignore'
  --exclude='99-System/Scripts/'
  --exclude='99-System/Skills/'
  --exclude='99-System/mcp-servers/'
  --exclude='99-System/integrations/'
  --exclude='99-System/ThinkingAgent/VectorStore/'
  --exclude='99-System/ThinkingAgent/HealthLogs/'
  --exclude='99-System/ThinkingAgent/Predictions/'
  --exclude='99-System/ThinkingAgent/belief_statistics.json'
  --exclude='99-System/ThinkingAgent/services'
  --exclude='99-System/ActionLoop/'
  --exclude='config/'
  --exclude='*.sqlite3'
  --exclude='*.bin'
  --exclude='*.pyc'
)

# 2. Obsidian → Git (Obsidian is source of truth for user-edited files)
log "Syncing Obsidian → Git..."
rsync -av --delete \
  "${EXCLUDES[@]}" \
  "$OB_VAULT/" "$GIT_REPO/" 2>&1 | tail -20

# 3. Git → Obsidian (pick up files added by server, e.g. Fireflies transcripts)
# Note: --update flag means only copy if the git version is newer
log "Syncing Git → Obsidian (server-generated files)..."
rsync -av --update \
  "${EXCLUDES[@]}" \
  "$GIT_REPO/" "$OB_VAULT/" 2>&1 | tail -20

# 3.5. Tidy Tasks.md (sort by priority/due, move completed to bottom, strip annotations)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIDY_SCRIPT="$SCRIPT_DIR/task-tidy.py"
if [ -f "$TIDY_SCRIPT" ]; then
  log "Tidying Tasks.md..."
  TASKS_PATH_REL="00-Tasks/Tasks.md"
  python3 "$TIDY_SCRIPT" "$GIT_REPO/$TASKS_PATH_REL" 2>&1
  # Also update the Obsidian copy
  cp "$GIT_REPO/$TASKS_PATH_REL" "$OB_VAULT/$TASKS_PATH_REL"
fi

# 4. Git commit + push if there are changes
TASKS_PATH_REL="00-Tasks/Tasks.md"
log "Tasks.md fingerprints before git check:"
file_fingerprint "$OB_VAULT/$TASKS_PATH_REL"
file_fingerprint "$GIT_REPO/$TASKS_PATH_REL"

log "Checking git status..."
cd "$GIT_REPO"

# Pull remote changes first (in case other systems pushed)
if [ -n "${GITHUB_PAT:-}" ]; then
  auth_header="$(printf 'x-access-token:%s' "$GITHUB_PAT" | base64 -w0)"
  log "Pulling remote changes..."
  git -c http.extraheader="AUTHORIZATION: basic ${auth_header}" pull --no-rebase origin main 2>&1 || true
fi

changed_files="$(git status --porcelain | awk '{print $2}' | tr '
' ',' | sed 's/,$//')"
if [ -n "$changed_files" ]; then
  git add -A
  git commit -m "Obsidian sync $(date '+%Y-%m-%d %H:%M') [${changed_files}]"
  if [ -n "${GITHUB_PAT:-}" ]; then
    auth_header="$(printf 'x-access-token:%s' "$GITHUB_PAT" | base64 -w0)"
    git -c http.extraheader="AUTHORIZATION: basic ${auth_header}" push origin main 2>&1
  else
    git push origin main 2>&1
  fi
  log "Git pushed."
else
  log "No git changes."
fi

# 5. Push back to Obsidian Cloud (in case Git added files)
log "Pushing to Obsidian Sync..."
run_ob_sync "Obsidian push"
log "Obsidian push complete."

log "Bridge sync done."

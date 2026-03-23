#!/usr/bin/env bash
set -euo pipefail

# Installs the "power pack" into an OpenClaw workspace.
# - Copies skills into <workspace>/skills/
# - Copies MCP server into <workspace>/secondbrain/99-System/mcp-servers/ (or another repo) if desired
# - Prints instructions for adding cron jobs

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/data/.openclaw/workspace}"
SKILLS_DIR="$WORKSPACE_DIR/skills"

mkdir -p "$SKILLS_DIR"

copy_skill() {
  local name="$1"
  echo "Installing skill: $name"
  rm -rf "$SKILLS_DIR/$name"
  cp -R "$REPO_DIR/openclaw/skills/$name" "$SKILLS_DIR/$name"
}

copy_skill "obsidian-git-bridge"
copy_skill "secondbrain-manager"
copy_skill "trello"

cat <<EOF

Installed skills into:
  $SKILLS_DIR

Next steps:
1) Configure your connectors (Google, Trello, Fireflies, etc) via env vars / secrets.
2) Add cron jobs: merge the templates from
   $REPO_DIR/openclaw/cron/jobs.template.json
   into your OpenClaw cron file (typically /data/.openclaw/cron/jobs.json).

Tip: keep Obsidian-canonical. Write to /data/.openclaw/obsidian-sync and mirror to git.
EOF
